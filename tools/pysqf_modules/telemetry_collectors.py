"""Daemon-side telemetry collectors (TELEMETRY_SPEC.md § Phase 2 E).

Everything the game cannot see about itself, sampled from inside pysqfd and handed to
`telemetry.push` like any other sample list:

    HostCollector   10 s   CPU %, load, memory, swap, disk, network -- from /proc, stdlib only
    ProcCollector   10 s   arma / hc / pysqfd / postgres: RSS, CPU %, threads, fds, uptime, running
    PgCollector     30 s   pg_stat_database, activity by state, DB size, live/dead rows per table
    EconCollector   60 s   money supply and object counts, read-only SQL on the game database

`Runner` owns the schedule: every collector runs in isolation, a raising collector counts
in ap_telemetry_collector_errors_total{collector} and the others still run. telemetry.py
starts one Runner thread at import when AP_TELEMETRY_COLLECTORS is not "0".

CONFIG
    AP_TELEMETRY_COLLECTORS   "0" disables all of this
    AP_TELEMETRY_PROCS        name=regex[,name=regex...] matched against /proc/<pid>/cmdline;
                              default covers arma (2.22 re-execs as rvMain), hc, pysqfd, postgres
    AP_TELEMETRY_DISKS        comma-separated mount points, default /home
    AP_TELEMETRY_TABLES       tables for row counts, default the game's hot ones

The /proc parsers are pure functions over text so the suite can pin them on captured
samples; the database collectors are exercised only against a live PostgreSQL.
"""

from __future__ import annotations

import os
import re
import time
from typing import Any, Callable, Dict, List, Optional, Sequence, Tuple

import pysqf

log = pysqf.log.getChild("telemetry.collectors")

Sample = List[Any]   # [name, labels(list of [k, v]), value]

DEFAULT_PROCS: Dict[str, str] = {
    "arma": r"(arma3server_x64|rvMain)(?!.*-client)",
    "hc": r"(arma3server_x64|rvMain).*-client",
    "pysqfd": r"pysqfd\.py",
    "postgres": r"(^|/)postgres(:| )",
}
DEFAULT_TABLES = ["players", "players_global", "vehicles", "houses", "gangs", "log",
                  "map_objects", "exchange", "eden_live_players", "bot_commands"]
_CLK_TCK = os.sysconf("SC_CLK_TCK") if hasattr(os, "sysconf") else 100
_PAGE = os.sysconf("SC_PAGE_SIZE") if hasattr(os, "sysconf") else 4096


def _read(path: str) -> str:
    with open(path, "r") as f:
        return f.read()


# --------------------------------------------------------------------------- /proc parsers

def parse_proc_stat(text: str) -> Dict[str, int]:
    """Aggregate cpu line -> {"busy": ticks, "idle": ticks}. idle = idle + iowait."""
    for line in text.splitlines():
        if line.startswith("cpu "):
            f = [int(x) for x in line.split()[1:]]
            f += [0] * (8 - len(f))
            user, nice, system, idle, iowait, irq, softirq, steal = f[:8]
            return {"busy": user + nice + system + irq + softirq + steal, "idle": idle + iowait}
    return {"busy": 0, "idle": 0}


def cpu_pct(prev: Dict[str, int], cur: Dict[str, int]) -> float:
    busy = cur["busy"] - prev["busy"]
    total = busy + (cur["idle"] - prev["idle"])
    if total <= 0:
        return 0.0
    return 100.0 * busy / total


def parse_meminfo(text: str) -> Dict[str, int]:
    kb: Dict[str, int] = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0].endswith(":"):
            try:
                kb[parts[0][:-1]] = int(parts[1])
            except ValueError:
                pass
    out = {
        "total": kb.get("MemTotal", 0) * 1024,
        "free": kb.get("MemFree", 0) * 1024,
        "available": kb.get("MemAvailable", 0) * 1024,
        "cached": kb.get("Cached", 0) * 1024,
        "buffers": kb.get("Buffers", 0) * 1024,
        "swap_total": kb.get("SwapTotal", 0) * 1024,
        "swap_free": kb.get("SwapFree", 0) * 1024,
    }
    out["used"] = out["total"] - out["available"]
    out["swap_used"] = out["swap_total"] - out["swap_free"]
    return out


def parse_net_dev(text: str) -> Tuple[int, int]:
    """(rx_bytes, tx_bytes) summed over every interface except lo."""
    rx = tx = 0
    for line in text.splitlines():
        if ":" not in line:
            continue
        name, rest = line.split(":", 1)
        if name.strip() == "lo":
            continue
        f = rest.split()
        if len(f) >= 9:
            rx += int(f[0])
            tx += int(f[8])
    return rx, tx


def parse_loadavg(text: str) -> Tuple[float, float, float]:
    f = text.split()
    return float(f[0]), float(f[1]), float(f[2])


def parse_uptime(text: str) -> float:
    return float(text.split()[0])


def parse_pid_stat(text: str) -> Dict[str, Any]:
    """/proc/<pid>/stat. comm sits in parens and may contain spaces or parens, so split on
    the LAST ')' and count fields from there (field 3 = state is index 0 of the tail)."""
    lp = text.index("(")
    rp = text.rindex(")")
    comm = text[lp + 1:rp]
    tail = text[rp + 2:].split()
    # tail[0]=state(3) ... utime=14 -> tail[11], stime=15 -> tail[12], num_threads=20 -> tail[17],
    # starttime=22 -> tail[19], rss=24 -> tail[21]
    return {
        "comm": comm,
        "state": tail[0],
        "utime": int(tail[11]),
        "stime": int(tail[12]),
        "threads": int(tail[17]),
        "starttime": int(tail[19]),
        "rss_pages": int(tail[21]),
    }


def match_procs(procs: Dict[str, str], cmdlines: Dict[int, str]) -> Dict[str, List[int]]:
    out: Dict[str, List[int]] = {name: [] for name in procs}
    compiled = {name: re.compile(rx) for name, rx in procs.items()}
    for pid in sorted(cmdlines):
        cmd = cmdlines[pid]
        for name, rx in compiled.items():
            if rx.search(cmd):
                out[name].append(pid)
    return out


def parse_procs_env(text: Optional[str]) -> Dict[str, str]:
    if not text:
        return dict(DEFAULT_PROCS)
    out: Dict[str, str] = {}
    for item in text.split(","):
        if "=" in item:
            k, v = item.split("=", 1)
            out[k.strip()] = v.strip()
    return out or dict(DEFAULT_PROCS)


def _s(name: str, labels: Sequence[Sequence[Any]], value: Any) -> Sample:
    return [name, [list(p) for p in labels], value]


# --------------------------------------------------------------------------- collectors

class HostCollector:
    def __init__(self, root: str = "/proc", disks: Optional[List[str]] = None) -> None:
        self.root = root
        self.disks = disks if disks is not None else [d for d in os.environ.get("AP_TELEMETRY_DISKS", "/home").split(",") if d]
        self._prev_cpu: Optional[Dict[str, int]] = None

    def sample(self) -> List[Sample]:
        out: List[Sample] = []
        cur = parse_proc_stat(_read(os.path.join(self.root, "stat")))
        if self._prev_cpu is not None:
            out.append(_s("ap_host_cpu_pct", [], round(cpu_pct(self._prev_cpu, cur), 2)))
        else:
            out.append(_s("ap_host_cpu_pct", [], 0.0))
        self._prev_cpu = cur
        l1, l5, l15 = parse_loadavg(_read(os.path.join(self.root, "loadavg")))
        out += [_s("ap_host_load", [["period", "1"]], l1), _s("ap_host_load", [["period", "5"]], l5),
                _s("ap_host_load", [["period", "15"]], l15)]
        m = parse_meminfo(_read(os.path.join(self.root, "meminfo")))
        for k in ("total", "used", "free", "available", "cached"):
            out.append(_s("ap_host_mem_bytes", [["kind", k]], m[k]))
        out.append(_s("ap_host_swap_bytes", [["kind", "total"]], m["swap_total"]))
        out.append(_s("ap_host_swap_bytes", [["kind", "used"]], m["swap_used"]))
        rx, tx = parse_net_dev(_read(os.path.join(self.root, "net", "dev")))
        out.append(_s("ap_host_net_bytes_total", [["dir", "rx"]], rx))
        out.append(_s("ap_host_net_bytes_total", [["dir", "tx"]], tx))
        out.append(_s("ap_host_uptime_s", [], parse_uptime(_read(os.path.join(self.root, "uptime")))))
        for d in self.disks:
            try:
                st = os.statvfs(d)
            except OSError:
                continue
            out.append(_s("ap_host_disk_bytes", [["path", d], ["kind", "total"]], st.f_blocks * st.f_frsize))
            out.append(_s("ap_host_disk_bytes", [["path", d], ["kind", "free"]], st.f_bavail * st.f_frsize))
        return out


class ProcCollector:
    def __init__(self, procs: Optional[Dict[str, str]] = None, root: str = "/proc") -> None:
        self.procs = procs if procs is not None else parse_procs_env(os.environ.get("AP_TELEMETRY_PROCS"))
        self.root = root
        self._prev: Dict[int, Tuple[int, float]] = {}   # pid -> (utime+stime ticks, monotonic)

    def _cmdlines(self) -> Dict[int, str]:
        out: Dict[int, str] = {}
        for entry in os.listdir(self.root):
            if not entry.isdigit():
                continue
            try:
                raw = open(os.path.join(self.root, entry, "cmdline"), "rb").read()
            except OSError:
                continue
            if raw:
                out[int(entry)] = raw.replace(b"\0", b" ").decode("utf-8", "replace").strip()
        return out

    def sample(self) -> List[Sample]:
        out: List[Sample] = []
        matched = match_procs(self.procs, self._cmdlines())
        now = time.monotonic()
        try:
            boot_uptime = parse_uptime(_read(os.path.join(self.root, "uptime")))
        except OSError:
            boot_uptime = 0.0
        seen = set()
        for name, pids in matched.items():
            rss = threads = fds = 0
            cpu = 0.0
            uptime = 0.0
            for pid in pids:
                seen.add(pid)
                try:
                    st = parse_pid_stat(_read(os.path.join(self.root, str(pid), "stat")))
                except (OSError, ValueError, IndexError):
                    continue
                rss += st["rss_pages"] * _PAGE
                threads += st["threads"]
                try:
                    fds += len(os.listdir(os.path.join(self.root, str(pid), "fd")))
                except OSError:
                    pass
                ticks = st["utime"] + st["stime"]
                prev = self._prev.get(pid)
                if prev is not None and now > prev[1]:
                    cpu += 100.0 * (ticks - prev[0]) / _CLK_TCK / (now - prev[1])
                self._prev[pid] = (ticks, now)
                uptime = max(uptime, boot_uptime - st["starttime"] / _CLK_TCK)
            l = [["proc", name]]
            out.append(_s("ap_proc_running", l, 1 if pids else 0))
            out.append(_s("ap_proc_count", l, len(pids)))
            out.append(_s("ap_proc_rss_bytes", l, rss))
            out.append(_s("ap_proc_cpu_pct", l, round(cpu, 2)))
            out.append(_s("ap_proc_threads", l, threads))
            out.append(_s("ap_proc_fds", l, fds))
            out.append(_s("ap_proc_uptime_s", l, round(uptime, 1)))
        for pid in list(self._prev):
            if pid not in seen:
                del self._prev[pid]
        return out


def _db():
    from pysqf import db
    return db


def _num(v: Any) -> float:
    if v is None:
        return 0
    if isinstance(v, bool):
        return int(v)
    if isinstance(v, (int, float)):
        return v
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0


class PgCollector:
    STAT_SQL = ("SELECT numbackends, xact_commit, xact_rollback, blks_read, blks_hit, tup_returned, "
                "tup_fetched, tup_inserted, tup_updated, tup_deleted, deadlocks, temp_bytes, "
                "pg_database_size(current_database()) AS db_bytes "
                "FROM pg_stat_database WHERE datname = current_database()")
    ACT_SQL = ("SELECT coalesce(state, 'none') AS state, count(*) AS n FROM pg_stat_activity "
               "WHERE datname = current_database() GROUP BY 1")
    TAB_SQL = ("SELECT relname, n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname = ANY(%s)")

    def __init__(self, tables: Optional[List[str]] = None) -> None:
        self.tables = tables if tables is not None else [t for t in os.environ.get("AP_TELEMETRY_TABLES", ",".join(DEFAULT_TABLES)).split(",") if t]

    def sample(self) -> List[Sample]:
        db = _db()
        t0 = time.monotonic()
        out: List[Sample] = []
        rows = db.query(self.STAT_SQL)
        if rows:
            r = rows[0]
            out.append(_s("ap_pg_backends", [], _num(r.get("numbackends"))))
            for col in ("xact_commit", "xact_rollback", "blks_read", "blks_hit", "tup_returned", "tup_fetched",
                        "tup_inserted", "tup_updated", "tup_deleted", "deadlocks", "temp_bytes"):
                out.append(_s("ap_pg_%s_total" % col, [], _num(r.get(col))))
            out.append(_s("ap_pg_db_bytes", [], _num(r.get("db_bytes"))))
        for r in db.query(self.ACT_SQL):
            out.append(_s("ap_pg_activity", [["state", str(r.get("state"))]], _num(r.get("n"))))
        for r in db.query(self.TAB_SQL, [self.tables]):
            l = [["table", str(r.get("relname"))]]
            out.append(_s("ap_pg_table_rows", l, _num(r.get("n_live_tup"))))
            out.append(_s("ap_pg_table_dead_rows", l, _num(r.get("n_dead_tup"))))
        out.append(_s("ap_pg_query_ms", [], round((time.monotonic() - t0) * 1000, 2)))
        return out


class EconCollector:
    PLAYERS_SQL = ("SELECT count(*) AS players, "
                   "count(*) FILTER (WHERE lastupdated >= now() - interval '24 hours') AS active_24h, "
                   "count(*) FILTER (WHERE lastupdated >= now() - interval '7 days') AS active_7d, "
                   "coalesce(sum(cash), 0) AS cash, coalesce(sum(bankacc), 0) AS bank FROM players")
    GANGS_SQL = "SELECT count(*) AS gangs, coalesce(sum(bank), 0) AS bank FROM gangs"
    VEH_SQL = ("SELECT count(*) AS total, count(*) FILTER (WHERE alive) AS alive, "
               "count(*) FILTER (WHERE active) AS active FROM vehicles")
    HOUSES_SQL = "SELECT count(*) AS houses FROM houses"
    EXCH_SQL = "SELECT count(*) AS listings FROM exchange"

    def sample(self) -> List[Sample]:
        db = _db()
        t0 = time.monotonic()
        out: List[Sample] = []
        p = db.query(self.PLAYERS_SQL)[0]
        cash, bank = _num(p.get("cash")), _num(p.get("bank"))
        out += [_s("ap_econ_players_total", [], _num(p.get("players"))),
                _s("ap_econ_players_active_24h", [], _num(p.get("active_24h"))),
                _s("ap_econ_players_active_7d", [], _num(p.get("active_7d"))),
                _s("ap_econ_cash_total", [], cash), _s("ap_econ_bank_total", [], bank)]
        g = db.query(self.GANGS_SQL)[0]
        gbank = _num(g.get("bank"))
        out += [_s("ap_econ_gangs", [], _num(g.get("gangs"))), _s("ap_econ_gang_bank_total", [], gbank),
                _s("ap_econ_money_supply", [], cash + bank + gbank)]
        v = db.query(self.VEH_SQL)[0]
        for k in ("total", "alive", "active"):
            out.append(_s("ap_econ_vehicles", [["state", k]], _num(v.get(k))))
        out.append(_s("ap_econ_houses", [], _num(db.query(self.HOUSES_SQL)[0].get("houses"))))
        out.append(_s("ap_econ_exchange_listings", [], _num(db.query(self.EXCH_SQL)[0].get("listings"))))
        out.append(_s("ap_econ_query_ms", [], round((time.monotonic() - t0) * 1000, 2)))
        return out


# --------------------------------------------------------------------------- runner

class Runner:
    """Schedules collectors by interval; isolates failures; pushes one batch per tick."""

    def __init__(self, push: Callable[[List[Sample]], Any], collectors: Sequence[Tuple[str, float, Callable[[], List[Sample]]]]) -> None:
        self.push = push
        self.collectors = list(collectors)
        self.next_run: Dict[str, float] = {name: 0.0 for name, _, _ in self.collectors}
        self.errors: Dict[str, int] = {name: 0 for name, _, _ in self.collectors}
        self.last_error: Dict[str, str] = {}
        self._last_log: Dict[str, float] = {}

    def tick(self, now: Optional[float] = None) -> None:
        now = time.monotonic() if now is None else now
        batch: List[Sample] = []
        for name, interval, fn in self.collectors:
            if now < self.next_run[name]:
                continue
            self.next_run[name] = now + interval
            try:
                batch.extend(fn())
            except Exception as e:  # noqa: BLE001 - isolation is the point
                self.errors[name] += 1
                self.last_error[name] = "%s: %s" % (type(e).__name__, e)
                if now - self._last_log.get(name, -1e9) >= 60:
                    self._last_log[name] = now
                    log.warning("collector %s failed (%d so far): %s", name, self.errors[name], self.last_error[name])
            batch.append(_s("ap_telemetry_collector_errors_total", [["collector", name]], self.errors[name]))
        if batch:
            self.push(batch)

    def run_forever(self, stop, period: float = 1.0) -> None:
        while not stop.is_set():
            try:
                self.tick()
            except Exception as e:  # noqa: BLE001
                log.warning("collector runner: %s: %s", type(e).__name__, e)
            stop.wait(period)


def default_collectors() -> List[Tuple[str, float, Callable[[], List[Sample]]]]:
    return [
        ("host", 10.0, HostCollector().sample),
        ("proc", 10.0, ProcCollector().sample),
        ("pg", 30.0, PgCollector().sample),
        ("econ", 60.0, EconCollector().sample),
    ]
