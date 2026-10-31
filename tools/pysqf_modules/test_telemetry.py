"""What VictoriaMetrics ACTUALLY RECEIVES from telemetry.push, against a local sink.

    PYTHONPATH=/home/timb/PySQF/python \\
    /home/timb/pysqf-venv/bin/python -m unittest tools.pysqf_modules.test_telemetry -v

Stdlib only: the sink is an http.server on a random loopback port that records
every POST body. No VictoriaMetrics needed -- the wire format it accepts
(Prometheus exposition lines with a millisecond timestamp) was measured against
v1.151.0 on 2026-09-09; these tests pin that exact text.

The contract these protect: the game hands over [name, labels, value] triples and
nothing that happens afterwards -- a dead sink, a full queue, a bad sample -- may
ever raise back into SQF or block the daemon's worker thread.
"""

from __future__ import annotations

import logging
import re
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# The module imports `pysqf` (for its logger and @export). run_checks.sh runs every
# tools/**/test_*.py with only the test's own directory on the path, so find the PySQF
# checkout the daemon runs from; without it, skip loudly rather than fail on an import.
import os, sys  # noqa: E402
os.environ.setdefault("AP_TELEMETRY_COLLECTORS", "0")   # no collector thread under test
_PYSQF_SRC = os.environ.get("PYSQF_SRC", "/home/timb/PySQF/python")
try:
    import pysqf  # noqa: F401
except ModuleNotFoundError:
    if os.path.isdir(_PYSQF_SRC):
        sys.path.insert(0, _PYSQF_SRC)
    try:
        import pysqf  # noqa: F401
    except ModuleNotFoundError:
        raise unittest.SkipTest("PySQF checkout not found (set PYSQF_SRC)")
_REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if _REPO not in sys.path:
    sys.path.insert(0, _REPO)

from tools.pysqf_modules import telemetry  # noqa: E402


class _Sink:
    """Records POST bodies; answers 204, or 503 while `fail` is set."""

    def __init__(self) -> None:
        self.bodies: list[str] = []
        self.fail = False
        sink = self

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):  # noqa: N802 - http.server API
                n = int(self.headers.get("Content-Length", "0"))
                body = self.rfile.read(n).decode("utf-8")
                if sink.fail:
                    self.send_response(503)
                    self.end_headers()
                    return
                sink.bodies.append(body)
                self.send_response(204)
                self.end_headers()

            def log_message(self, *_):  # silence the server
                pass

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.url = "http://127.0.0.1:%d/api/v1/import/prometheus" % self.server.server_address[1]
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def lines(self) -> list[str]:
        out: list[str] = []
        for b in self.bodies:
            out.extend(l for l in b.split("\n") if l)
        return out

    def close(self) -> None:
        self.server.shutdown()
        self.server.server_close()


FIXED_MS = 1700000000000


class TelemetryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sink = _Sink()
        logging.disable(logging.CRITICAL)   # the sink-down cases log a warning by design

    @classmethod
    def tearDownClass(cls):
        logging.disable(logging.NOTSET)
        cls.sink.close()

    def setUp(self):
        self.sink.bodies.clear()
        self.sink.fail = False
        telemetry._reset()
        telemetry._configure(url=self.sink.url, host="testhost", enabled=True, queue_max=20000)
        telemetry._now_ms = lambda: FIXED_MS

    # -- format ---------------------------------------------------------------

    def test_push_formats_prometheus_lines_with_stamp_and_host(self):
        ok = telemetry.push([["ap_x", {"a": "b"}, 1.5], ["ap_y", [["k", "v"]], 3]])
        self.assertIs(ok, True)
        telemetry.flush()
        lines = self.sink.lines()
        self.assertIn('ap_x{a="b",host="testhost"} 1.5 %d' % FIXED_MS, lines)
        self.assertIn('ap_y{k="v",host="testhost"} 3 %d' % FIXED_MS, lines)

    def test_sample_without_labels_gets_only_host(self):
        telemetry.push([["ap_bare", [], 7]])
        telemetry.flush()
        self.assertIn('ap_bare{host="testhost"} 7 %d' % FIXED_MS, self.sink.lines())

    def test_explicit_host_label_is_kept(self):
        telemetry.push([["ap_x", {"host": "other"}, 1]])
        telemetry.flush()
        self.assertIn('ap_x{host="other"} 1 %d' % FIXED_MS, self.sink.lines())

    def test_label_values_are_escaped(self):
        telemetry.push([["ap_x", {"name": 'Q"uo\\te\nnl'}, 1]])
        telemetry.flush()
        self.assertIn('ap_x{name="Q\\"uo\\\\te\\nnl",host="testhost"} 1 %d' % FIXED_MS, self.sink.lines())

    def test_bool_values_become_one_and_zero(self):
        telemetry.push([["ap_t", [], True], ["ap_f", [], False]])
        telemetry.flush()
        lines = self.sink.lines()
        self.assertIn('ap_t{host="testhost"} 1 %d' % FIXED_MS, lines)
        self.assertIn('ap_f{host="testhost"} 0 %d' % FIXED_MS, lines)

    def test_float_values_keep_precision_and_integers_stay_plain(self):
        telemetry.push([["ap_a", [], 12.3456789], ["ap_b", [], 1048576.0]])
        telemetry.flush()
        lines = self.sink.lines()
        self.assertIn('ap_a{host="testhost"} 12.3456789 %d' % FIXED_MS, lines)
        self.assertIn('ap_b{host="testhost"} 1048576 %d' % FIXED_MS, lines)

    # -- refusal, never raising ----------------------------------------------

    def test_bad_samples_are_counted_and_skipped_but_good_ones_still_go(self):
        ok = telemetry.push([
            ["bad name", [], 1],              # space in metric name
            ["ap_ok", {"bad-key": "v"}, 1],   # dash in label key
            ["ap_str", [], "12"],             # string value
            ["ap_nan", [], float("nan")],     # non-finite
            "not a triple",                   # wrong shape
            ["ap_good", [], 2],
        ])
        self.assertIs(ok, True)
        st = telemetry.flush()
        self.assertEqual(st["bad_samples"], 5)
        self.assertEqual([l for l in self.sink.lines() if l.startswith("ap_good")],
                         ['ap_good{host="testhost"} 2 %d' % FIXED_MS])

    def test_sink_down_never_raises_retries_once_then_drops(self):
        self.sink.fail = True
        telemetry.push([["ap_x", [], 1], ["ap_y", [], 2]])
        st1 = telemetry.flush()          # first attempt fails, batch kept for one retry
        self.assertEqual(st1["failed_posts"], 1)
        self.assertEqual(st1["dropped_lines"], 0)
        st2 = telemetry.flush()          # retry fails -> dropped
        self.assertEqual(st2["failed_posts"], 2)
        self.assertEqual(st2["dropped_lines"], 2)
        self.assertEqual(self.sink.bodies, [])
        self.sink.fail = False
        telemetry.push([["ap_z", [], 3]])
        st3 = telemetry.flush()
        self.assertEqual(st3["sent_lines"], 1)
        self.assertEqual(len(self.sink.bodies), 1)

    def test_retry_batch_is_sent_when_sink_recovers(self):
        self.sink.fail = True
        telemetry.push([["ap_x", [], 1]])
        telemetry.flush()
        self.sink.fail = False
        telemetry.push([["ap_y", [], 2]])
        st = telemetry.flush()
        self.assertEqual(st["dropped_lines"], 0)
        self.assertEqual(st["sent_lines"], 2)
        lines = self.sink.lines()
        self.assertTrue(any(l.startswith("ap_x{") for l in lines))
        self.assertTrue(any(l.startswith("ap_y{") for l in lines))

    def test_queue_is_bounded_and_drops_oldest(self):
        telemetry._configure(queue_max=5)
        telemetry.push([["ap_n%d" % i, [], i] for i in range(8)])
        st = telemetry.flush()
        self.assertEqual(st["dropped_lines"], 3)
        names = [l.split("{")[0] for l in self.sink.lines() if l.startswith("ap_n")]
        self.assertEqual(names, ["ap_n3", "ap_n4", "ap_n5", "ap_n6", "ap_n7"])

    def test_three_pushes_flush_as_one_post(self):
        telemetry.push([["ap_a", [], 1]])
        telemetry.push([["ap_b", [], 2]])
        telemetry.push([["ap_c", [], 3]])
        telemetry.flush()
        self.assertEqual(len(self.sink.bodies), 1)
        self.assertEqual(sum(1 for l in self.sink.lines() if re.match(r"ap_[abc]\{", l)), 3)

    def test_disabled_counts_and_sends_nothing(self):
        telemetry._configure(enabled=False)
        ok = telemetry.push([["ap_x", [], 1]])
        self.assertIs(ok, True)
        st = telemetry.flush()
        self.assertEqual(st["disabled_lines"], 1)
        self.assertEqual(self.sink.bodies, [])

    def test_empty_push_is_fine_and_posts_nothing(self):
        self.assertIs(telemetry.push([]), True)
        telemetry.flush()
        self.assertEqual(self.sink.bodies, [])

    # -- self-metrics --------------------------------------------------------

    def test_self_metrics_ride_along_with_every_batch(self):
        telemetry.push([["ap_x", [], 1]])
        telemetry.flush()
        lines = self.sink.lines()
        self.assertTrue(any(l.startswith('ap_telemetry_queue_lines{host="testhost"}') for l in lines))
        self.assertTrue(any(l.startswith('ap_telemetry_sent_lines_total{host="testhost"}') for l in lines))
        self.assertTrue(any(l.startswith('ap_telemetry_dropped_lines_total{host="testhost"}') for l in lines))
        self.assertTrue(any(l.startswith('ap_telemetry_failed_posts_total{host="testhost"}') for l in lines))

    def test_stats_reports_counters(self):
        telemetry.push([["ap_x", [], 1]])
        telemetry.flush()
        st = telemetry.stats()
        self.assertEqual(st["sent_lines"], 1)
        self.assertEqual(st["sent_batches"], 1)
        self.assertEqual(st["queue_lines"], 0)
        self.assertEqual(st["url"], self.sink.url)

    # -- background flusher --------------------------------------------------

    def test_background_thread_delivers_without_explicit_flush(self):
        telemetry._configure(flush_every=0.05)
        telemetry.push([["ap_bg", [], 9]])
        deadline = threading.Event()
        for _ in range(40):
            if any(l.startswith("ap_bg{") for l in self.sink.lines()):
                break
            deadline.wait(0.05)
        self.assertTrue(any(l.startswith("ap_bg{") for l in self.sink.lines()))


if __name__ == "__main__":
    unittest.main()
