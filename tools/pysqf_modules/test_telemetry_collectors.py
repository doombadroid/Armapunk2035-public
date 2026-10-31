"""Daemon-side collectors (TELEMETRY_SPEC.md § Phase 2 E): host, processes, PostgreSQL, economy.

    PYTHONPATH=/home/timb/PySQF/python \\
    /home/timb/pysqf-venv/bin/python -m unittest tools.pysqf_modules.test_telemetry_collectors -v

The /proc parsers are tested on captured text, so the suite runs anywhere. The two
database collectors need a live PostgreSQL: they run only when PYSQF_DB_DSN is set
and skip loudly otherwise -- a skipped database test is reported, never silently green.

On the box, read the DSN WHOLE. It is a space-separated libpq string, and shell-sourcing
pysqfd.env (`set -a; . file`) splits it into five separate variables -- user= and
password= never reach psycopg and the failure reads "no password supplied". systemd's
EnvironmentFile keeps the line intact, which is why the daemon itself is fine:

    export PYSQF_DB_DSN="$(grep '^PYSQF_DB_DSN=' ~/.config/armapunk/pysqfd.env | cut -d= -f2-)"
"""

from __future__ import annotations

import os
import sys
import unittest

os.environ.setdefault("AP_TELEMETRY_COLLECTORS", "0")   # the module under test must not start threads here

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

from tools.pysqf_modules import telemetry_collectors as tc  # noqa: E402

PROC_STAT_A = "cpu  1000 50 500 8000 100 0 20 0 0 0\ncpu0 500 25 250 4000 50 0 10 0 0 0\n"
PROC_STAT_B = "cpu  1300 50 600 8800 100 0 20 0 0 0\ncpu0 650 25 300 4400 50 0 10 0 0 0\n"
MEMINFO = ("MemTotal:       11534336 kB\nMemFree:         6291456 kB\nMemAvailable:    7340032 kB\n"
           "Buffers:          102400 kB\nCached:          1048576 kB\nSwapTotal:       2097152 kB\n"
           "SwapFree:        2097152 kB\n")
NET_DEV = ("Inter-|   Receive                                                |  Transmit\n"
           " face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed\n"
           "    lo: 5000 10 0 0 0 0 0 0 5000 10 0 0 0 0 0 0\n"
           "  eth0: 1000000 500 0 0 0 0 0 0 200000 300 0 0 0 0 0 0\n"
           "docker0: 7 1 0 0 0 0 0 0 9 1 0 0 0 0 0 0\n")
# /proc/<pid>/stat: comm in parens can contain spaces and parens; fields after it are positional.
PID_STAT = ("4242 (arma3server_x (2)) S 1 4242 4242 0 -1 4194560 12345 0 0 0 "
            "3000 500 0 0 20 0 41 0 123456 987654321 25000 18446744073709551615 "
            "1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0")
CMDLINES = {
    1: "/home/timb/arma3server_live/arma3server_x64 -config=server.cfg -port=2302 -serverMod=@AP_server",
    2: "/home/timb/arma3server_live/arma3server_x64 -client -connect=127.0.0.1 -port=2302",
    3: "/home/timb/pysqf-venv/bin/python pysqfd.py --modules pysqf.db,apdb,webpages,telemetry",
    4: "postgres: checkpointer",
    5: "postgres: armapunk armapunk 127.0.0.1(51234) idle",
    6: "/usr/bin/python3 something_else.py",
}


class ParserTests(unittest.TestCase):
    def test_cpu_pct_between_two_stat_samples(self):
        a = tc.parse_proc_stat(PROC_STAT_A)
        b = tc.parse_proc_stat(PROC_STAT_B)
        # busy delta = (1300+50+600+20) - (1000+50+500+20) = 400; total delta = 400 + idle 800 = 1200
        self.assertAlmostEqual(tc.cpu_pct(a, b), 100.0 * 400 / 1200, places=3)

    def test_cpu_pct_with_no_elapsed_ticks_is_zero_not_a_crash(self):
        a = tc.parse_proc_stat(PROC_STAT_A)
        self.assertEqual(tc.cpu_pct(a, a), 0.0)

    def test_meminfo_in_bytes(self):
        m = tc.parse_meminfo(MEMINFO)
        self.assertEqual(m["total"], 11534336 * 1024)
        self.assertEqual(m["available"], 7340032 * 1024)
        self.assertEqual(m["swap_total"], 2097152 * 1024)
        self.assertEqual(m["used"], (11534336 - 7340032) * 1024)

    def test_net_dev_sums_every_interface_but_loopback(self):
        rx, tx = tc.parse_net_dev(NET_DEV)
        self.assertEqual((rx, tx), (1000007, 200009))

    def test_loadavg_and_uptime(self):
        self.assertEqual(tc.parse_loadavg("0.52 0.61 0.70 2/1234 56789\n"), (0.52, 0.61, 0.70))
        self.assertEqual(tc.parse_uptime("12345.67 98765.43\n"), 12345.67)

    def test_pid_stat_survives_spaces_and_parens_in_comm(self):
        p = tc.parse_pid_stat(PID_STAT)
        self.assertEqual(p["comm"], "arma3server_x (2)")
        self.assertEqual(p["utime"], 3000)
        self.assertEqual(p["stime"], 500)
        self.assertEqual(p["threads"], 41)
        self.assertEqual(p["starttime"], 123456)
        self.assertEqual(p["rss_pages"], 25000)

    def test_match_procs_default_patterns(self):
        got = tc.match_procs(tc.DEFAULT_PROCS, CMDLINES)
        self.assertEqual(got["arma"], [1])
        self.assertEqual(got["hc"], [2])
        self.assertEqual(got["pysqfd"], [3])
        self.assertEqual(got["postgres"], [4, 5])

    def test_match_procs_reports_missing_as_empty_list(self):
        got = tc.match_procs({"nothing": r"no_such_binary"}, CMDLINES)
        self.assertEqual(got["nothing"], [])


class RunnerTests(unittest.TestCase):
    def test_collectors_are_isolated_and_errors_are_counted(self):
        pushed = []

        def good():
            return [["ap_test_good", [], 1]]

        def bad():
            raise RuntimeError("boom")

        runner = tc.Runner(push=pushed.append, collectors=[("good", 10, good), ("bad", 10, bad)])
        runner.tick(now=1000.0)
        flat = [s for batch in pushed for s in batch]
        names = [s[0] for s in flat]
        self.assertIn("ap_test_good", names)
        err = {dict(s[1])["collector"]: s[2] for s in flat if s[0] == "ap_telemetry_collector_errors_total"}
        self.assertEqual(err, {"good": 0, "bad": 1})   # a zero for the healthy one is the point
        self.assertEqual(runner.errors["bad"], 1)

    def test_intervals_are_respected(self):
        calls = []
        runner = tc.Runner(push=lambda s: None, collectors=[("fast", 10, lambda: calls.append("f") or []),
                                                           ("slow", 60, lambda: calls.append("s") or [])])
        runner.tick(now=0.0)       # both run first time
        runner.tick(now=10.0)      # fast only
        runner.tick(now=30.0)      # fast only
        runner.tick(now=60.0)      # both
        self.assertEqual(calls, ["f", "s", "f", "f", "f", "s"])

    def test_host_collector_emits_expected_names(self):
        names = {s[0] for s in tc.HostCollector(root="/proc").sample()}
        for n in ("ap_host_cpu_pct", "ap_host_load", "ap_host_mem_bytes", "ap_host_swap_bytes",
                  "ap_host_net_bytes_total", "ap_host_uptime_s", "ap_host_disk_bytes"):
            self.assertIn(n, names)

    def test_proc_collector_finds_this_process(self):
        me = "python.*test_telemetry_collectors|unittest"
        col = tc.ProcCollector(procs={"self": me}, root="/proc")
        col.sample()                       # first sample primes cpu counters
        samples = col.sample()
        running = [s for s in samples if s[0] == "ap_proc_running" and s[1] == [["proc", "self"]]]
        self.assertEqual(running[0][2], 1)
        rss = [s for s in samples if s[0] == "ap_proc_rss_bytes" and s[1] == [["proc", "self"]]]
        self.assertGreater(rss[0][2], 1_000_000)


@unittest.skipUnless(os.environ.get("PYSQF_DB_DSN"), "PYSQF_DB_DSN not set -- database collectors not exercised")
class DatabaseCollectorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from pysqf import db
        db.configure(dsn=os.environ["PYSQF_DB_DSN"])

    def test_pg_collector_reports_backends_and_tables(self):
        samples = tc.PgCollector().sample()
        names = {s[0] for s in samples}
        for n in ("ap_pg_backends", "ap_pg_xact_commit_total", "ap_pg_db_bytes", "ap_pg_table_rows", "ap_pg_query_ms"):
            self.assertIn(n, names)
        tables = {dict(s[1])["table"] for s in samples if s[0] == "ap_pg_table_rows"}
        self.assertIn("players", tables)

    def test_econ_collector_reports_money_supply(self):
        samples = tc.EconCollector().sample()
        by = {s[0]: s[2] for s in samples if not s[1]}
        self.assertGreater(by["ap_econ_players_total"], 0)
        self.assertEqual(by["ap_econ_money_supply"], by["ap_econ_cash_total"] + by["ap_econ_bank_total"] + by["ap_econ_gang_bank_total"])
        self.assertIn("ap_econ_query_ms", by)


if __name__ == "__main__":
    unittest.main()
