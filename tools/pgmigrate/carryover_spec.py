"""The `--spec` file `reconcile.py` requires, generated from the carry-over policy.

Purpose:
    Define `RECONCILE_SPEC` so the independent auditor can actually be run:
    `reconcile.py --dump … --output …/jsonl --spec carryover_spec.py`.

WHY THIS EXISTS:
    `reconcile.py` is the strongest check in the package — its own dump parser,
    its own decoder, player ids compared one at a time rather than as totals —
    and it could not be run at all, because it requires a spec and no spec file
    existed anywhere in the repository. The rehearsal loop therefore verified row
    counts and nothing else, which is precisely the check that cannot tell one
    player lost plus one player duplicated from a clean migration.

    It is GENERATED rather than written by hand. A hand-written spec is a second
    copy of the carry-over policy, and the two drift; the failure that drift
    produces is the worst one available — a table that quietly stopped carrying,
    reconciling clean because the spec still said to expect zero rows. The
    independence that matters is in the parser and the decoder, not in retyping
    the rules.

    Rehearsal knob: `ALLOW_UNRESOLVED`. With the product decisions unmade, the
    DECIDE tables have no auditor rule — an open question is not a disposition —
    so building a spec at all requires saying out loud that this is a rehearsal.
    Set it to False for the real run, and `rules.reconcile_spec()` will refuse
    until every table has been decided.

Usage:
    python3 reconcile.py --dump live.sql --output out/jsonl \\
        --spec carryover_spec.py --report reconcile.json

    # or, to pin the real run:
    PGMIGRATE_ALLOW_UNRESOLVED=0 python3 reconcile.py ...

STATUS:
    Unvalidated. No dump of the live database exists in this repository, so this
    spec has never been applied to real data — see the STATUS block in
    reconcile.py, which applies with equal force to everything generated here.
"""

from __future__ import annotations

import os

try:  # imported as part of the package
    from .rules import reconcile_spec
except ImportError:  # loaded by path, which is how reconcile.py --spec does it
    import os as _os
    import sys as _sys

    _sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
    from rules import reconcile_spec  # type: ignore

#: Rehearsal by default, because the decisions are unmade today (DECISIONS.md).
#: Turning this off is how the real run refuses to audit a policy with holes in it.
ALLOW_UNRESOLVED = os.environ.get("PGMIGRATE_ALLOW_UNRESOLVED", "1") != "0"

RECONCILE_SPEC = reconcile_spec(allow_unresolved_tables=ALLOW_UNRESOLVED)
