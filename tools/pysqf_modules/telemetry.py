"""Ship game metrics to VictoriaMetrics, off the game's thread.

    ["telemetry.push", [[name, labels, value], ...]] call APS_fnc_pysqfCall   -> true
    ["telemetry.stats", []]                          call APS_fnc_pysqfCall   -> {counters}
    ["telemetry.flush", []]                          call APS_fnc_pysqfCall   -> {counters}

This is the "job server" half of the pattern from the Arma Discord thread that
prompted it: the game hands over numbers and does not care what happens next.
Everything after `push` returns is this module's problem -- the HTTP POST runs on
a daemon thread, a dead sink costs the game a counter and nothing else, and no
input, however malformed, raises back through the pysqf boundary.

WIRE FORMAT
    Prometheus exposition lines with a millisecond timestamp, POSTed to
    VictoriaMetrics' /api/v1/import/prometheus (measured against v1.151.0 on
    2026-09-09: 204, series queryable). One line per sample:

        ap_server_fps{machine="server",host="live"} 47 1757460000000

    The timestamp is THIS process's wall clock at receipt. SQF numbers are 32-bit
    floats, so an epoch in milliseconds (1.7e12) cannot cross the boundary intact;
    the game never sends one.

SAMPLE SHAPE
    [name, labels, value]
      name    ^[a-zA-Z_:][a-zA-Z0-9_:]*$
      labels  JSON object, or a list of [key, value] pairs (what SQF naturally
              builds); keys ^[a-zA-Z_][a-zA-Z0-9_]*$, values any scalar (escaped)
      value   number or bool (-> 1/0); must be finite
    A sample failing any of that is counted in `bad_samples` and skipped. The
    `host` label is added from AP_TELEMETRY_HOST unless the sample carries one.

DELIVERY
    A bounded queue (AP_TELEMETRY_QUEUE lines, oldest dropped) feeds one flusher
    thread that posts every AP_TELEMETRY_FLUSH_S seconds or as soon as
    AP_TELEMETRY_FLUSH_LINES are waiting. A failed batch is kept for exactly one
    retry on the next tick, then dropped -- a sink that is down for an hour must
    not turn into an hour of memory growth. Failures log at most once a minute.
    The thread starts on the first push, so `pysqfd --check` imports this without
    side effects.

CONFIG (environment, read at import; tests override with _configure)
    AP_TELEMETRY_URL          default http://127.0.0.1:8428/api/v1/import/prometheus
    AP_TELEMETRY_HOST         default socket.gethostname()
    AP_TELEMETRY_ENABLED      "0"/"false"/"no" disables (push still answers true)
    AP_TELEMETRY_QUEUE        default 20000 lines
    AP_TELEMETRY_FLUSH_S      default 1.0
    AP_TELEMETRY_FLUSH_LINES  default 500
    AP_TELEMETRY_TIMEOUT_S    default 2.0  (per POST)
"""

from __future__ import annotations

import collections
import math
import os
import re
import socket
import threading
import time
import urllib.error
import urllib.request
from typing import Any, Dict, List, Optional, Tuple

import pysqf

log = pysqf.log.getChild("telemetry")

_NAME_RE = re.compile(r"^[a-zA-Z_:][a-zA-Z0-9_:]*$")
_LABEL_RE = re.compile(r"^[a-zA-Z_][a-zA-Z0-9_]*$")
_LOG_EVERY_S = 60.0


def _env_bool(name: str, default: bool) -> bool:
    v = os.environ.get(name)
    if v is None:
        return default
    return v.strip().lower() not in ("0", "false", "no", "")


class _State:
    """All mutable state in one place so tests can reset it wholesale."""

    def __init__(self) -> None:
        self.url = os.environ.get("AP_TELEMETRY_URL", "http://127.0.0.1:8428/api/v1/import/prometheus")
        self.host = os.environ.get("AP_TELEMETRY_HOST") or socket.gethostname()
        self.enabled = _env_bool("AP_TELEMETRY_ENABLED", True)
        self.queue_max = int(os.environ.get("AP_TELEMETRY_QUEUE", "20000"))
        self.flush_every = float(os.environ.get("AP_TELEMETRY_FLUSH_S", "1.0"))
        self.flush_at = int(os.environ.get("AP_TELEMETRY_FLUSH_LINES", "500"))
        self.timeout = float(os.environ.get("AP_TELEMETRY_TIMEOUT_S", "2.0"))

        self.lock = threading.Lock()
        self.queue: collections.deque = collections.deque()
        self.retry: Optional[List[str]] = None   # one failed batch awaiting its single retry
        self.wake = threading.Event()
        self.stop = threading.Event()
        self.thread: Optional[threading.Thread] = None
        self.post_lock = threading.Lock()         # one POST in flight at a time
        self.last_err_log = 0.0
        self.counters: Dict[str, int] = {
            "received_samples": 0, "bad_samples": 0, "disabled_lines": 0,
            "sent_lines": 0, "sent_batches": 0, "failed_posts": 0, "dropped_lines": 0,
        }
        self.last_error = ""
        self.last_ok_ms = 0


_s = _State()


def _now_ms() -> int:
    return int(time.time() * 1000)


# --------------------------------------------------------------------------- formatting

def _escape(v: Any) -> str:
    return str(v).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def _format_value(v: Any) -> Optional[str]:
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        if not math.isfinite(v):
            return None
        if v.is_integer() and abs(v) < 1e15:
            return str(int(v))
        return repr(v)
    return None


def _format_sample(sample: Any, ts_ms: int, host: str) -> Optional[str]:
    """One exposition line, or None when the sample is not usable."""
    if not isinstance(sample, (list, tuple)) or len(sample) != 3:
        return None
    name, labels, value = sample
    if not isinstance(name, str) or not _NAME_RE.match(name):
        return None
    if isinstance(labels, dict):
        items = list(labels.items())
    elif isinstance(labels, (list, tuple)):
        items = []
        for pair in labels:
            if not isinstance(pair, (list, tuple)) or len(pair) != 2:
                return None
            items.append((pair[0], pair[1]))
    else:
        return None
    parts = []
    seen_host = False
    for k, v in items:
        if not isinstance(k, str) or not _LABEL_RE.match(k):
            return None
        if k == "host":
            seen_host = True
        parts.append('%s="%s"' % (k, _escape(v)))
    if not seen_host:
        parts.append('host="%s"' % _escape(host))
    val = _format_value(value)
    if val is None:
        return None
    return "%s{%s} %s %d" % (name, ",".join(parts), val, ts_ms)


def _self_metrics(ts_ms: int, host: str, queue_len: int) -> List[str]:
    c = _s.counters
    return [
        _format_sample(["ap_telemetry_queue_lines", [], queue_len], ts_ms, host),
        _format_sample(["ap_telemetry_sent_lines_total", [], c["sent_lines"]], ts_ms, host),
        _format_sample(["ap_telemetry_dropped_lines_total", [], c["dropped_lines"]], ts_ms, host),
        _format_sample(["ap_telemetry_failed_posts_total", [], c["failed_posts"]], ts_ms, host),
    ]


# --------------------------------------------------------------------------- delivery

def _post(lines: List[str]) -> bool:
    body = ("\n".join(lines) + "\n").encode("utf-8")
    req = urllib.request.Request(_s.url, data=body, method="POST",
                                 headers={"Content-Type": "text/plain; charset=utf-8"})
    try:
        with urllib.request.urlopen(req, timeout=_s.timeout) as resp:
            return 200 <= resp.status < 300
    except urllib.error.HTTPError as e:
        _note_error("HTTP %s from %s" % (e.code, _s.url))
        e.close()   # the response body is an open file; leaving it is a ResourceWarning
        return False
    except (urllib.error.URLError, OSError, ValueError) as e:
        _note_error("%s: %s" % (type(e).__name__, e))
        return False


def _note_error(msg: str) -> None:
    _s.last_error = msg
    now = time.monotonic()
    if now - _s.last_err_log >= _LOG_EVERY_S:
        _s.last_err_log = now
        log.warning("post to %s failed: %s (failed_posts=%d dropped_lines=%d)",
                    _s.url, msg, _s.counters["failed_posts"], _s.counters["dropped_lines"])


def _drain() -> Tuple[List[str], int, bool]:
    """Take everything queued (plus the retry batch, first) under the lock.

    Returns (batch, lines still queued, whether the batch carries a retry). The
    retry fact travels as a value, not as a marker on the list object: the batch
    is a fresh list every time, so anything hung on the old object is lost.
    """
    with _s.lock:
        batch: List[str] = []
        had_retry = bool(_s.retry)
        if _s.retry:
            batch.extend(_s.retry)
            _s.retry = None
        n = len(_s.queue)
        for _ in range(n):
            batch.append(_s.queue.popleft())
        queue_len = len(_s.queue)
    return batch, queue_len, had_retry


def _flush_once() -> None:
    """Drain and POST one batch. Serialised so the thread and flush() never overlap."""
    with _s.post_lock:
        batch, queue_len, had_retry = _drain()
        if not batch:
            return
        payload = batch + [l for l in _self_metrics(_now_ms(), _s.host, queue_len) if l]
        if _post(payload):
            with _s.lock:
                _s.counters["sent_lines"] += len(batch)
                _s.counters["sent_batches"] += 1
                _s.last_ok_ms = _now_ms()
            return
        with _s.lock:
            _s.counters["failed_posts"] += 1
            if had_retry:
                # Second failure in a row for these lines: drop the whole batch.
                # Bounded memory beats completeness for operational telemetry.
                _s.counters["dropped_lines"] += len(batch)
            else:
                _s.retry = batch


def _run() -> None:
    while not _s.stop.is_set():
        _s.wake.wait(_s.flush_every)
        _s.wake.clear()
        try:
            _flush_once()
        except Exception as e:  # noqa: BLE001 - the thread must never die
            _note_error("flusher: %s: %s" % (type(e).__name__, e))


def _ensure_thread() -> None:
    if _s.thread is not None and _s.thread.is_alive():
        return
    with _s.lock:
        if _s.thread is not None and _s.thread.is_alive():
            return
        _s.stop.clear()
        _s.thread = threading.Thread(target=_run, name="telemetry-flush", daemon=True)
        _s.thread.start()


# --------------------------------------------------------------------------- exports

@pysqf.export
def push(samples: Any = None) -> bool:
    """Queue samples. Always answers True: delivery is not the caller's concern."""
    if not isinstance(samples, (list, tuple)) or not samples:
        return True
    ts = _now_ms()
    host = _s.host
    lines: List[str] = []
    bad = 0
    for sample in samples:
        line = _format_sample(sample, ts, host)
        if line is None:
            bad += 1
        else:
            lines.append(line)
    with _s.lock:
        _s.counters["received_samples"] += len(samples)
        _s.counters["bad_samples"] += bad
        if not _s.enabled:
            _s.counters["disabled_lines"] += len(lines)
            return True
        for line in lines:
            if len(_s.queue) >= _s.queue_max:
                _s.queue.popleft()
                _s.counters["dropped_lines"] += 1
            _s.queue.append(line)
        wake = len(_s.queue) >= _s.flush_at
    _ensure_thread()
    if wake:
        _s.wake.set()
    return True


@pysqf.export
def flush() -> Dict[str, Any]:
    """Drain synchronously (one POST attempt) and report counters."""
    _flush_once()
    return stats()


@pysqf.export
def stats() -> Dict[str, Any]:
    with _s.lock:
        out: Dict[str, Any] = dict(_s.counters)
        out["queue_lines"] = len(_s.queue)
        out["retry_lines"] = len(_s.retry) if _s.retry else 0
    out["url"] = _s.url
    out["host"] = _s.host
    out["enabled"] = _s.enabled
    out["last_error"] = _s.last_error
    out["last_ok_ms"] = _s.last_ok_ms
    out["thread_alive"] = bool(_s.thread and _s.thread.is_alive())
    return out


# --------------------------------------------------------------------------- daemon-side collectors

_collectors_thread: Optional[threading.Thread] = None


def _start_collectors() -> None:
    """Host / process / PostgreSQL / economy samplers (telemetry_collectors.py) on one daemon
    thread, started at import unless AP_TELEMETRY_COLLECTORS=0. They push through `push`
    like the game does, so a dead sink costs them nothing either."""
    global _collectors_thread
    if _collectors_thread is not None:
        return
    if not _s.enabled or not _env_bool("AP_TELEMETRY_COLLECTORS", True):
        return
    try:
        try:
            import telemetry_collectors as tc            # daemon: tools/pysqf_modules on PYTHONPATH
        except ModuleNotFoundError:
            from tools.pysqf_modules import telemetry_collectors as tc   # tests: repo root on path
    except Exception as e:  # noqa: BLE001 - collectors are optional
        log.warning("collectors not started: %s: %s", type(e).__name__, e)
        return
    runner = tc.Runner(push=push, collectors=tc.default_collectors())
    stop = threading.Event()
    _collectors_thread = threading.Thread(target=runner.run_forever, args=(stop,), name="telemetry-collectors", daemon=True)
    _collectors_thread.start()
    log.info("collectors started: %s", ", ".join(n for n, _, _ in runner.collectors))


_start_collectors()


# --------------------------------------------------------------------------- test hooks

def _configure(**kw: Any) -> None:
    """Override url/host/enabled/queue_max/flush_every/flush_at/timeout (tests)."""
    for k, v in kw.items():
        if not hasattr(_s, k) or k in ("lock", "queue", "thread", "wake", "stop", "counters"):
            raise ValueError("not configurable: %s" % k)
        setattr(_s, k, v)


def _reset() -> None:
    """Stop the flusher and start from a clean state (tests)."""
    global _s, _now_ms
    old = _s
    old.stop.set()
    old.wake.set()
    if old.thread is not None and old.thread.is_alive():
        old.thread.join(timeout=2.0)
    _s = _State()
    _now_ms = lambda: int(time.time() * 1000)  # noqa: E731 - module-level patch point
