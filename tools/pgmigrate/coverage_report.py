#!/usr/bin/env python3
"""Runtime coverage ledger: which corpus statements actually ran, and how.

"Sweep proven" (the plan's Phase-P exit criterion) means every corpus
statement was observed executing on PostgreSQL without failure -- live play,
dbSoak, boot, any source -- over a log window. This reads the dev server log
(fn_asyncQuery diag_logs every statement as `SQL Query: <realised text>`;
failures as `QUERY FAILED`) and matches the realised lines back to their
corpus templates.

Matching: a corpus template's `%N` placeholders become non-greedy wildcards;
everything else must match verbatim. Whitespace is normalised on both sides.
A log line that matches no template is reported too -- either the corpus is
stale (run harvest_corpus.py) or something is building SQL outside the
harvested string literals.

    python3 coverage_report.py /home/timb/arma3server_dev/loonydev.log [more.log ...]
    python3 coverage_report.py --uncovered-only <logs...>
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CORPUS = os.path.join(HERE, "sqlcorpus", "corpus.json")

LOG_QUERY = re.compile(r'"SQL Query: (.*)"\s*$')
LOG_FAILED = re.compile(r"QUERY FAILED: (.*?) -- query: (.*)")


def _norm(sql: str) -> str:
    return re.sub(r"\s+", " ", sql).strip()


def template_regex(sql: str) -> re.Pattern:
    """Corpus template -> regex over a normalised log line.

    `'%1'` (a quoted placeholder) and bare `%1` both become lazy wildcards.
    The corpus stores what the SQF `format` call sees, so this is the whole
    grammar -- there is no escaping subtlety beyond regex-escaping the rest.
    """
    out, last = [], 0
    for m in re.finditer(r"'%\d+'|%\d+", sql):
        out.append(re.escape(_norm(sql[last:m.start()])))
        out.append(".*?")
        last = m.end()
    out.append(re.escape(_norm(sql[last:])))
    # re.escape doubles spaces' significance; collapse escaped-space runs to \s+
    pattern = re.sub(r"(?:\\ )+", r"\\s+", "".join(out))
    # Two tiers: exact, and prefix. The prefix tier exists because diag_log
    # truncates very long lines (the ArmaQuest chunk INSERTs, ~1.6k chars) and
    # because a `partial: true` template IS a prefix by construction. A prefix
    # hit still proves the statement ran; it cannot prove the tail.
    return (re.compile("^%s$" % pattern, re.I | re.S),
            re.compile("^%s" % pattern.split("\\s+VALUES", 1)[0], re.I | re.S))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("logs", nargs="+")
    ap.add_argument("--uncovered-only", action="store_true")
    args = ap.parse_args()

    corpus = json.load(open(CORPUS, encoding="utf-8"))
    entries = [(e, template_regex(e["sql"])) for e in corpus]
    hits = {id(e): 0 for e, _ in entries}
    failures, unmatched = [], {}

    for path in args.logs:
        for line in open(path, encoding="utf-8", errors="replace"):
            fm = LOG_FAILED.search(line)
            if fm:
                failures.append((fm.group(1)[:80], _norm(fm.group(2))[:160]))
                continue
            qm = LOG_QUERY.search(line)
            if not qm:
                continue
            text = _norm(qm.group(1))
            for e, (rx_full, rx_prefix) in entries:
                if rx_full.match(text) or (
                        (e.get("partial") or len(text) > 900) and rx_prefix.match(text)):
                    hits[id(e)] += 1
                    break
            else:
                unmatched[text[:160]] = unmatched.get(text[:160], 0) + 1

    covered = sum(1 for e, _ in entries if hits[id(e)])
    print("-- coverage: %d/%d corpus statements observed; %d log lines matched no template; %d failures"
          % (covered, len(entries),
             sum(unmatched.values()), len(failures)))

    if not args.uncovered_only:
        for text, n in sorted(unmatched.items(), key=lambda kv: -kv[1])[:20]:
            print("UNMATCHED x%-4d %s" % (n, text))
        for why, text in failures[:20]:
            print("FAILED   %s\n         %s" % (text, why))

    print("-- uncovered (never observed in these logs):")
    for e, _ in entries:
        if not hits[id(e)]:
            print("   %s:%d: %s" % (e["file"], e["line"], e["sql"][:110]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
