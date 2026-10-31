#!/usr/bin/env bash
# tools/run_checks.sh -- the aggregate automated-check harness for Armapunk 2035.
#
# Runs every offline, automatable check this repo has and prints ONE summary, with a non-zero
# exit if anything failed:
#
#   python3 tools/aq_check.py       -- ArmaQuest content structural validator
#   python3 tools/vend_check.py     -- the 12 vending machines: model + signs + wiring + comp + shop
#   python3 tools/aq_verbcheck.py   -- action-objective verb -> aq_fnc_event call-site gate
#   tools/sqf_balance.py            -- Arma-aware bracket balance, every .sqf under mission/ and
#                                       server/ (the project's own tokenizer-based checker; the
#                                       standing order requires it over naive brace counting,
#                                       which miscounts braces inside strings and comments)
#   tools/nested_exitwith_check.py  -- gates whose refusal is an exitWith nested in an if-then block
#                                       (it leaves only that block; the guarded code still runs)
#   every tools/**/test_*.py        -- via `python3 -m unittest <path>`, one process per file
#
# Each check prints one PASS/FAIL line; full output is shown only for a check that failed, so a
# clean run stays a genuine summary instead of a multi-thousand-line transcript (sqf_balance.py
# alone touches well over a thousand files).
#
# The vendored mission/Armapunk2035.Malden/ArmaQuest/ tree is excluded from the balance scan on
# purpose: it is upstream's code, replaced wholesale by scratchpad/vendor_armaquest.py on the next
# re-vendor (see that tree's own VENDORED.txt and aq_content.hpp's header comment), so a fault in
# it is not this repository's to fix and reporting it here would misattribute someone else's file
# as our failure.
#
# tools/pysqf_modules/ is a branch-dependent vendor drop that does not exist on every branch of
# this repo. This script never hard-codes that path -- `find` naturally returns nothing for a
# directory that isn't there, so its tests run when present and are skipped without error when
# absent, with no special-casing needed either way.
#
# WHAT THIS CANNOT DO. There is no SQF runtime, parser or test runner outside Arma itself, so
# nothing here executes a line of SQF. This checks structure: content grammar, cross-references,
# bracket balance, and the Python tooling's own test suites. The engine-side gates -- actually
# compiling every .sqf, aq_fnc_validate and aq_fnc_reachability running for real at preInit, the
# extDB3/store round-trip -- only run on a real deploy-and-boot cycle. A green run here means
# "nothing structurally wrong that a machine can see from the repository, in well under a
# second", which is worth having ahead of that ~2 minute cycle, and is NOT a substitute for it.
set -uo pipefail   # deliberately not -e: a failing check must not stop the rest of the run
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

PASS=0
FAIL=0
FAILED_NAMES=()

run_check() {
    # $1 = display name for the summary, the rest = the command to run.
    local name="$1"; shift
    local out rc
    printf '  %-52s ' "$name"
    out=$("$@" 2>&1)
    rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "PASS"
        PASS=$((PASS + 1))
    else
        echo "FAIL (exit $rc)"
        FAIL=$((FAIL + 1))
        FAILED_NAMES+=("$name")
        printf '%s\n' "$out" | sed 's/^/      /'
        echo
    fi
}

echo "== ArmaQuest content =="
run_check "aq_check.py" python3 tools/aq_check.py
run_check "aq_verbcheck.py" python3 tools/aq_verbcheck.py
# 3D printer: recipe/schematic bijection, no currency in a parts list, no ingredient cycles, no
# output shared with the Factory, and the recursive backbone walk actually nesting. The ported
# system shipped 39 unreachable recipes and two silent case bugs for want of exactly this.
run_check "fab_check.py (printer recipe table)" python3 tools/fab_check.py
run_check "vend_check.py (vending machines)" python3 tools/vend_check.py
# deck-app wave: deck.html grows by scripted insertion; a bad splice must fail
# here, not as a dead phone in game.
run_check "html_js_check.py (ui/html scripts parse)" python3 tools/html_js_check.py
run_check "dialog_reachability.py (createDialog targets at config root)" python3 tools/dialog_reachability.py
# CfgRE allowedTargets = 1 limits the target, not the sender: every server -> client receiver in
# tools/cfgre_server_only.txt must refuse a remoteExec that did not come from the server.
run_check "cfgre_origin_check.py (server->client receivers guard the sender)" python3 tools/cfgre_origin_check.py
# The connect-time cache worker warms the weapon shop's thumbnails from a classname list
# lifted out of fn_weaponShopCfg.sqf. That array cannot be read at runtime (it is a private
# local behind the shop's gating prologue), so this is what stops the two drifting: a stale
# list warms the wrong weapons and looks exactly like the stall it was written to fix.
run_check "gen_warm_catalogue.py --check (warm list tracks the shop)" python3 tools/gen_warm_catalogue.py --check
run_check "hudlayout_parity.py (HUD editor CSS matches the live one)" python3 tools/hudlayout_parity.py
run_check "gen_dashboards.py --check (Grafana dashboards track the generator)" python3 deploy/telemetry/gen_dashboards.py --check
run_check "test_hudedit.js (HUD editor drag/clamp/payload)" node tools/test_hudedit.js
# 3D map mesh library: format, index sanity, tri budget, coverage, and the gen=
# stamp that ties malden_bld.txt's positional mesh ids to the library they were
# baked from. Without the stamp check, a re-harvest that skips the re-bake
# renumbers every mid and renders church meshes on sheds with no error anywhere.
run_check "test_bake_map_meshes.py (3D map mesh library)" python3 tools/test_bake_map_meshes.py
# mapdb: the table is the only source of placed objects. The files it replaced must not
# come back into the mission tree (a resurrected malden_buildings.sqf spawns every custom
# building twice), and every path in deploy/pbo_exclude.txt must exist -- the packer matches
# the list exactly, so a typo there silently ships the file instead of failing.
run_check "map_pbo_gate.py (no table data in the mission tree)" python3 tools/map_pbo_gate.py
# pg conversion: the SQL corpus must track the SQF -- a port batch that edits a
# statement without re-harvesting ships a PREPARE gate that proves nothing.
run_check "harvest_corpus.py --check (SQL corpus current)" python3 tools/pgmigrate/harvest_corpus.py --check
# T3: the permanent sweep lint -- the port to native PostgreSQL is DONE and this
# is what keeps it done. Any MySQL-ism entering the tree fails the build.
run_check "harvest_corpus.py --lint (no MySQL-isms)" python3 tools/pgmigrate/harvest_corpus.py --lint
# A client's publicVariable overwrites server globals, so none may be spliced into server SQL.
run_check "sql_global_check.py (no globals in server SQL)" python3 tools/sql_global_check.py
# The vendored PySQF bridge must equal a fresh render of the PINNED tag. It once lagged the pin
# with a stale exponent regex that rewrote 1.78561e+09 as 1.78560997867520 in every statement.
# Needs the upstream checkout; skipped (not failed) without one, same policy as the DSN gate.
if [ -d "${PYSQF_SRC:-$HOME/PySQF}/.git" ]; then
    run_check "vendor_pysqf.py --check (vendored PySQF matches the pin)" python3 scratchpad/vendor_pysqf.py --check
else
    echo "  vendor_pysqf.py --check                            SKIP (no PySQF checkout)"
fi
# The PREPARE gate needs the dev PostgreSQL and the psycopg venv; with no DSN
# exported it is skipped rather than failed, same policy as the bridge suite.
if [ -n "${PYSQF_DB_DSN:-}" ]; then
    GATE_PY="${PYSQF_VENV:-/home/timb/pysqf-venv}/bin/python"
    [ -x "$GATE_PY" ] || GATE_PY=python3
    run_check "prepare_gate.py (corpus EXPLAINs on PostgreSQL)" "$GATE_PY" tools/pgmigrate/prepare_gate.py
    run_check "test_apdb_bridge.py (seam contract, live PostgreSQL)" \
        env PYTHONPATH="/home/timb/PySQF/python" "$GATE_PY" -m unittest tools/pysqf_modules/test_apdb_bridge.py
else
    echo "  prepare_gate.py                                    SKIP (PYSQF_DB_DSN not set)"
fi

echo
echo "== SQF balance (Arma-aware) =="
mapfile -t SQF_FILES < <(find mission server -name '*.sqf' -not -path '*/ArmaQuest/*' 2>/dev/null | sort)
if [ "${#SQF_FILES[@]}" -eq 0 ]; then
    echo "  no .sqf files found under mission/ or server/ -- skipping"
else
    run_check "sqf_balance.py (${#SQF_FILES[@]} files, ArmaQuest/ vendor tree excluded)" \
        python3 tools/sqf_balance.py "${SQF_FILES[@]}"
fi

# exitWith leaves only the innermost scope: a refusal nested in `if .. then {}` lets the code after
# the block run anyway. Two admin/loot gates shipped that way (2026-09-26 audit).
run_check "nested_exitwith_check.py (nested exitWith gates)" python3 tools/nested_exitwith_check.py

echo
echo "== Python test suites =="
mapfile -t TEST_FILES < <(find tools -name 'test_*.py' 2>/dev/null | sort)
if [ "${#TEST_FILES[@]}" -eq 0 ]; then
    echo "  no tools/**/test_*.py found -- nothing to run"
else
    for t in "${TEST_FILES[@]}"; do
        # Two test styles live here and running only one silently skips the other.
        # unittest-style modules define TestCase classes; SCRIPT-style ones assert
        # on import and report through the exit code. `python3 -m unittest` on a
        # script-style file reports "NO TESTS RAN" and exits 0 -- a PASS that
        # checked nothing. test_sqf_balance.py is exactly that: 0 tests under
        # unittest, 33/33 when run directly. Detect the style and run each the way
        # it expects, so neither is quietly unchecked.
        if grep -q "unittest.TestCase" "$t" 2>/dev/null; then
            # The map tests import their siblings by bare name (import map_push); run from
            # the repo root that only works with the test's own directory on the path.
            run_check "unittest ${t#tools/}" env PYTHONPATH="$(dirname "$t")" python3 -m unittest "$t"
        else
            run_check "script  ${t#tools/}" python3 "$t"
        fi
    done
fi

echo
echo "-- $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    echo "-- failing:"
    for n in "${FAILED_NAMES[@]}"; do
        echo "     - $n"
    done
    exit 1
fi
exit 0
