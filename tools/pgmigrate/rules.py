"""pgmigrate carry-over policy — what crosses the map change, and what does not.

WHY THIS EXISTS
    The hard part of this ETL is not engines, it is semantics. The new world is a
    different map, so every row anchored to the old map's coordinates is dead on
    arrival, and every row that is *not* anchored is a product decision about
    somebody's property. Written as code, those decisions disappear into the
    transform: an `if table == "houses": continue` looks like an implementation
    detail and is actually a policy that deletes what players paid for.

    So the policy lives here, as data. One entry per source table, each naming a
    mode, the columns dropped and why, the columns transcoded out of the old text
    codec, and the columns a human still has to rule on. That makes the whole
    carry-over reviewable in one file and diffable in one commit — the owner can
    read what will happen to their players' data without reading any transform
    code, and a change of mind shows up in `git diff` as a change of policy.

    It also closes the silent-drop hole. `validate()` fails when the dump contains
    a table with no entry here, so a table added upstream — and the repo already
    does not know its own full schema (postgres_plan.md §2) — cannot be dropped by
    omission. Silence is not a disposition.

    Two mechanisms are implemented with their policies deliberately left blank:
    compensation for property destroyed by the map change, and a balance scaling
    factor for an overhauled economy. Both refuse rather than default, because a
    default here is a policy nobody chose (see DECISIONS.md).

Usage:
    >>> import rules
    >>> rules.CARRY["vehicles"].mode
    'carry_transform'
    >>> rules.CARRY["vehicles"].force["active"]      # garaged, never spatial
    False
    >>> rules.CARRY["houses"].mode
    'drop'
    >>> rules.check(["players", "houses", "brand_new_table"])[0].message
    "source table 'brand_new_table' has no entry in CARRY ..."

    Enforcing the policy at the start of a run:

    >>> rules.validate(dump_tables)                  # doctest: +SKIP
    TransformError: error: brand_new_table: source table ... has no entry in CARRY

STATUS
    Unvalidated. No live dump exists in this repo. Nothing here has met real data:
    the table roster was read out of `sql/`, `deploy/run-boot2.sh` and the runtime
    DDL in SQF, all three of which are known to be incomplete. The live dump is
    expected to contain tables this file has never heard of — that is precisely
    the case `validate()` is built to fail on, not a defect in the dump.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal
from fractions import Fraction
from typing import Callable, Iterable, Mapping, MutableMapping

# Generated purchase-price table (gen_prices.py). Same dual-import shape the rest
# of the package uses: this module is imported both as `pgmigrate.rules` and as a
# bare `rules` from inside the directory, and the compensation policy is not
# optional plumbing — if it cannot load, the run must not start.
try:  # pragma: no cover - import plumbing
    from . import prices
except ImportError:  # pragma: no cover
    import prices

try:  # imported as `pgmigrate.rules`
    from .model import Issue, Row, TransformError
except ImportError:  # imported flat, e.g. by test_rules.py or a REPL in this dir
    from model import Issue, Row, TransformError


# ---------------------------------------------------------------------------
# UNDECIDED — the sentinel that makes an unmade decision loud
# ---------------------------------------------------------------------------


class _Undecided:
    """A decision nobody has made. Falsy, unmistakable in a traceback.

    Deliberately not `None`: `None` reads as "no value needed" at a glance, and
    the entire point of these hooks is that a missing value is a missing product
    decision that must stop the run.
    """

    _instance = None

    def __new__(cls) -> "_Undecided":
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __bool__(self) -> bool:
        return False

    def __repr__(self) -> str:
        return "UNDECIDED"


UNDECIDED = _Undecided()


# ---------------------------------------------------------------------------
# Modes and codecs
# ---------------------------------------------------------------------------

#: Rows carry unchanged, mapped by column NAME. Dialect/type conversion only.
CARRY_AS_IS = "carry_as_is"
#: Rows carry with drops, renames, transcodes, defaults and/or forced values.
CARRY_TRANSFORM = "carry_transform"
#: Table does not carry. Requires `reason`; may register a `compensate` source.
DROP = "drop"
#: Unresolved product decision. The ETL refuses to run while any of these remain.
DECIDE = "decide"

MODES = (CARRY_AS_IS, CARRY_TRANSFORM, DROP, DECIDE)

#: Target encoding for every column currently holding the bespoke array codec.
#: The old encoding is transcoded here, once, and never emitted (plan §7.1).
JSONB = "jsonb"

#: A JSON text literal for a target column the source has no data for. The loader
#: casts it; it is a string here so this file stays free of engine types.
JSONB_EMPTY_ARRAY = "[]"

#: What an EMPTY legacy value means once transcoded. `mres.decode_strict` returns
#: `[]` for one (and `None` only for SQL NULL), so every transcoded column carries
#: this policy unless its Carry entry overrides it. Recorded because the auditor
#: has to know: an empty inventory and an inventory that failed to decode must not
#: be allowed to look the same, and "the reconciler assumed" is not a policy.
EMPTY_ENCODED_AS_ARRAY = "empty_array"
EMPTY_ENCODED_AS_NULL = "null"
EMPTY_ENCODED_POLICIES = (EMPTY_ENCODED_AS_ARRAY, EMPTY_ENCODED_AS_NULL)


@dataclass(frozen=True)
class Carry:
    """The disposition of one source table. One of these per table in the dump.

    Fields are policy, not mechanism — the transform reads them, but a reviewer
    should be able to understand the whole carry-over from this file alone.

    mode
        One of MODES.
    natural_key
        The columns identifying a row for idempotent load and for naming the row
        in an error. Recorded even on DROP tables, so a compensation failure can
        say *which* house it choked on.
    drop
        Columns whose VALUE does not carry, with the reason in `notes`.
        Map-anchored coordinates, old-deployment identity, in-flight session
        state.

        This drops the value, NOT the column. The target runs the same game code
        against a different map: it writes `players.position` on every logout and
        reads `lastupdated` in its login query, so a target schema without those
        columns is a schema the server cannot use — and `players.id` is the
        identity primary key, which must exist to be generated. What must not
        happen is the OLD value arriving. So the column is emitted, nothing
        populates it, and the target's own default or identity fills it in;
        `etl` checks against the translated schema that every such column can
        actually take that (nullable, defaulted or identity) and lists them in
        the report so "nothing populates this" is stated rather than assumed.
    transcode
        column -> target codec. Every entry is a column holding the old array
        text codec; the value is always JSONB.
    booleans
        `tinyint(1)` columns that are genuinely flags and become `boolean`.
        Opt-in on purpose: `intake_path` is declared `tinyint(1)` and holds
        0/1/2/3/9, so a blanket tinyint(1)->boolean rule would destroy it. Any
        tinyint not listed here stays an integer.
    currency
        Exact-integer money columns. Reconciliation sums these; nothing in the
        path may turn one into a float (plan §7.3, §7.4).
    scaled
        Currency columns that BALANCE_SCALE applies to. A subset of `currency`:
        a stored balance is scaled, a historical ledger amount is not.
    rename
        source column -> target column, BY NAME. Never by position.
    drop_is_value_only
        Read the `drop` docstring: a dropped column's VALUE does not carry, but
        the column itself still exists in the target — see `add_columns` for the
        opposite case. This field does not exist; the note is here because that
        distinction has been misread once already.
    add_columns
        column -> PostgreSQL column definition, for target columns the source has
        no counterpart for at all (`players.cyberdeck_modules` exists only in this
        project). `ddl` emits these into the CREATE TABLE; without that the ETL
        writes a COPY header naming a column the schema does not have, and the
        load fails at `psql` time with every internal check green. Every key of
        `defaults` must appear here.
    defaults
        Target columns the source lacks, with the value to write.
    force
        Columns overwritten on every carried row regardless of source value.
        `vehicles.active = False` lives here: the rows carry only because they are
        non-spatial while garaged. A forced value for a column listed in
        `booleans` must itself be a bool — an int here reaches the emitter as
        `0`/`1` where every other flag is `true`/`false`, and the auditor's
        structural comparison is type-strict about exactly that.
    empty_encoded
        column -> what an empty legacy value becomes, for any transcoded column
        whose answer is not EMPTY_ENCODED_AS_ARRAY.
    reason
        Required for DROP and DECIDE. Why it does not carry / what is unresolved.
    question
        Required for DECIDE. The question a human must answer, phrased so it can
        be answered yes/no or with an option from DECISIONS.md.
    compensate
        Name of a registered COMPENSATION_SOURCES entry, when dropping these rows
        destroys something a player paid for.
    notes
        Free text for the reviewer. This is a policy document; use it.
    """

    mode: str
    natural_key: tuple[str, ...] = ()
    drop: tuple[str, ...] = ()
    transcode: Mapping[str, str] = field(default_factory=dict)
    booleans: tuple[str, ...] = ()
    currency: tuple[str, ...] = ()
    scaled: tuple[str, ...] = ()
    rename: Mapping[str, str] = field(default_factory=dict)
    add_columns: Mapping[str, str] = field(default_factory=dict)
    defaults: Mapping[str, object] = field(default_factory=dict)
    force: Mapping[str, object] = field(default_factory=dict)
    empty_encoded: Mapping[str, str] = field(default_factory=dict)
    reason: str | None = None
    question: str | None = None
    compensate: str | None = None
    #: Name of a ROW_REWRITES entry, for a transform that is conditional on the
    #: row's own values and therefore cannot be a column `force`. A NAME rather
    #: than a callable so CARRY stays declarative, greppable and diffable, and so
    #: _selfcheck can prove the name resolves.
    rewrite: str | None = None
    #: Target table name, when the TABLE itself was renamed between the source
    #: deployment and this one. Column renames are `rename`; this is the table.
    target_table: str | None = None
    #: Whether the TABLE has to exist in the new database at all.
    #:
    #: Not the same question as whether its ROWS carry, and conflating the two
    #: is how 27 tables the game actively queries -- houses, turf, log,
    #: server_control -- came within one deploy of not existing. A DROP table is
    #: usually still a table this game writes to; it just starts empty. Set this
    #: False only for tables that belong to another system entirely.
    target_exists: bool = True
    notes: str = ""

    def __post_init__(self) -> None:
        if self.mode not in MODES:
            raise ValueError("unknown carry mode %r (expected one of %s)" % (self.mode, ", ".join(MODES)))
        if self.mode in (DROP, DECIDE) and not self.reason:
            raise ValueError("mode %s requires a reason" % self.mode)
        if self.mode == DECIDE and not self.question:
            raise ValueError("mode %s requires the question a human must answer" % self.mode)
        if self.target_table and not self.carries:
            raise ValueError("a dropped table cannot have a target name (%r)" % self.target_table)
        if self.rewrite and self.mode != CARRY_TRANSFORM:
            raise ValueError("mode %s cannot declare a row rewrite — use %s" % (self.mode, CARRY_TRANSFORM))
        if self.mode == CARRY_AS_IS and (self.drop or self.transcode or self.rename or self.force
                                         or self.add_columns or self.defaults):
            raise ValueError("mode %s cannot drop, transcode, rename, force or add columns — use %s" % (CARRY_AS_IS, CARRY_TRANSFORM))
        for column, codec in self.transcode.items():
            if codec != JSONB:
                raise ValueError("column %r transcodes to %r; the only target encoding is %r" % (column, codec, JSONB))
        overlap = set(self.drop) & set(self.transcode)
        if overlap:
            raise ValueError("columns both dropped and transcoded: %s" % ", ".join(sorted(overlap)))
        overlap = set(self.drop) & set(self.force)
        if overlap:
            raise ValueError("columns both dropped and forced: %s" % ", ".join(sorted(overlap)))
        overlap = set(self.drop) & set(self.currency)
        if overlap:
            raise ValueError("columns both dropped and reconciled as currency: %s" % ", ".join(sorted(overlap)))
        missing = set(self.scaled) - set(self.currency)
        if missing:
            raise ValueError("scaled columns must also be declared currency: %s" % ", ".join(sorted(missing)))
        # A forced flag must be a bool. `force={"active": 0}` on a column listed
        # in `booleans` survives the transform's boolean coercion (force runs
        # after it) and lands in the output as `0` where every other flag is
        # `false` — which the auditor's type-strict structural comparison then
        # reports against the one table whose rows it was hardest to check.
        for column, value in self.force.items():
            if column in self.booleans and not isinstance(value, bool):
                raise ValueError(
                    "force[%r] = %r on a column declared boolean; forced flags must be "
                    "True/False, not %s" % (column, value, type(value).__name__))
        # A target column the source has no counterpart for must declare its type,
        # or `ddl` cannot emit it and the COPY names a column that does not exist.
        undeclared = set(self.defaults) - set(self.add_columns)
        if undeclared:
            raise ValueError(
                "defaults for target-only columns with no add_columns type declaration: %s"
                % ", ".join(sorted(undeclared)))
        overlap = set(self.add_columns) & set(self.drop)
        if overlap:
            raise ValueError("columns both added and dropped: %s" % ", ".join(sorted(overlap)))
        unknown = set(self.empty_encoded) - set(self.transcode)
        if unknown:
            raise ValueError("empty_encoded names columns that are not transcoded: %s"
                             % ", ".join(sorted(unknown)))
        for column, policy in self.empty_encoded.items():
            if policy not in EMPTY_ENCODED_POLICIES:
                raise ValueError("empty_encoded[%r] = %r; expected one of %s"
                                 % (column, policy, ", ".join(EMPTY_ENCODED_POLICIES)))

    def empty_policy(self, column: str) -> str:
        """What an empty legacy value in `column` becomes. See EMPTY_ENCODED_AS_ARRAY."""
        if column not in self.transcode:
            raise KeyError("%s is not a transcoded column" % column)
        return self.empty_encoded.get(column, EMPTY_ENCODED_AS_ARRAY)

    @property
    def carries(self) -> bool:
        """True when rows from this table reach the target."""
        return self.mode in (CARRY_AS_IS, CARRY_TRANSFORM)


# ---------------------------------------------------------------------------
# CARRY — the policy itself
# ---------------------------------------------------------------------------
#
# Sources for the roster, all of them incomplete on their own:
#   sql/looneybin_dev_schema.sql        36 tables, structure dump 2026-06-26
#   sql/*.sql fragments                 dated after that dump
#   deploy/run-boot2.sh                 columns that exist only in a boot script
#   runtime DDL in SQF                  tables that exist in no .sql file at all
#
# The live database has more tables than this (plan §2 counts 49). Every one of
# them must appear here before the ETL will run; that is what validate() is for.

CARRY: dict[str, Carry] = {
    # -- accounts, money, progression ------------------------------------------------
    "players": Carry(
        mode=CARRY_TRANSFORM,
        natural_key=("playerid",),
        drop=(
            "id",            # source surrogate key; playerid is the natural key and the only stable one
            "instance",      # old deployment's instance id; meaningless on the new box
            "position",      # MAP-ANCHORED: old-map coordinates. Reset to spawn — nothing maps between maps
            "alive",         # in-flight session state at the freeze instant
            "damage",        # ditto — nobody should carry a bleed-out across a map change
            "lastupdated",   # target regenerates it; carrying it makes "last seen" lie about the new server
        ),
        transcode={
            "aliases": JSONB,
            "civ_gear": JSONB,
            "cop_gear": JSONB,
            "med_gear": JSONB,
            "civ_licenses": JSONB,
            "cop_licenses": JSONB,
            "med_licenses": JSONB,
            "civ_talents": JSONB,
            "cop_talents": JSONB,
            "med_talents": JSONB,
            "medic_talents": JSONB,
            "infamy_talents": JSONB,
            "pre_talents": JSONB,
            "prestige": JSONB,
            "arrested": JSONB,
            "crimes": JSONB,
            "gov_data": JSONB,
            "completed_quests": JSONB,
            "progress_quests": JSONB,
        },
        booleans=("isswat", "isfirefighter", "new_player", "isdetective", "casino_banned"),
        currency=("cash", "bankacc", "new_drachma"),
        scaled=("cash", "bankacc", "new_drachma"),
        # THE FACTION SWEEP RENAMED THESE COLUMNS AND THE SOURCE DOES NOT KNOW.
        # Checked against the live schema 2026-08-15: live has `isswat`/`isdetective`,
        # and the fork's SQF reads `ismaxtac`/`isscd` and has ZERO references to the
        # old names. Without this rename the new server queries a column the carried
        # table does not have, and every MaxTac operator and every SCD detective
        # silently loses their role on day one -- no error, just an empty result.
        rename={"isswat": "ismaxtac", "isdetective": "isscd"},
        # A column the SOURCE does not have and this game DOES. `qh_detonate_cd`
        # exists only on the fork's own database; the source box never had it,
        # so nothing carries into it -- but `APS_fnc_qhSRV` writes it on every
        # quickhack detonate, and a column the game writes and the schema lacks
        # is an error per write, forever. It was listed under `drop` until
        # 2026-08-15, which dropped a value that was never there and left the
        # column uncreated.
        add_columns={"qh_detonate_cd": "timestamp NULL"},
        notes=(
            "The account row. `new_drachma` is decimal(20,4) and must round-trip exactly — carry it as "
            "Decimal from parse to emit and never through a float (plan §7.4). `cash`/`bankacc` are bigint "
            "and hold values above the 16,777,216 float-exact range (§7.3). "
            "`intake_path`/`intake_step` are declared tinyint(1)/tinyint unsigned but hold 0/1/2/3/9 and "
            "0..255 — they are NOT booleans; that is why `booleans` is an allowlist. "
            "`cyberdeck_modules` WAS declared here as a target-only column. The live schema was read "
            "on 2026-08-15 and already has it, so it maps like any other column; adding it would have "
            "collided with the source's own. "
            "`booleans` and `drop` name SOURCE columns, so they keep the pre-rename names -- the "
            "transform applies them before `rename`, which runs last."
        ),
    ),
    "players_global": Carry(
        mode=CARRY_TRANSFORM,
        natural_key=("playerid",),
        drop=(),
        transcode={
            "achievements": JSONB,
            "stats": JSONB,
            "lifetime_stats": JSONB,
            "honor_talents": JSONB,
            "lootrewards": JSONB,
            "keys": JSONB,
            "mailbox": JSONB,
        },
        booleans=("betatester",),
        currency=("wealth",),
        scaled=("wealth",),
        notes=(
            "Cross-side account state: permissions, achievements, lifetime stats. `wealth` is a stored "
            "total, so it scales with the balances it summarises — if it did not, a scaled economy would "
            "show every player a wealth figure that contradicts their bank. "
            "`keys` holds vehicle keys by plate, which is why it carries: plates carry with `vehicles`."
        ),
    ),
    "player_names": Carry(
        mode=CARRY_AS_IS,
        natural_key=("playerid", "name"),
        notes="Alias history. Non-spatial, cheap, and the only record of who somebody used to be.",
    ),
    "talent_points": Carry(
        mode=CARRY_AS_IS,
        natural_key=("pid",),
        currency=(),
        notes=(
            "Talent points bought with money (1st = 1.0m, +500k each). Purchased entitlement carries; "
            "`points` is a count, not currency, so BALANCE_SCALE does not touch it. If balances are "
            "scaled down, these points were bought at old prices — that asymmetry is decision 3's, not "
            "this table's."
        ),
    ),
    "loadouts": Carry(
        mode=CARRY_TRANSFORM,
        natural_key=("pid", "side", "slot"),
        drop=("id",),
        transcode={"gear": JSONB},
        notes=(
            "Saved loadouts. `currency` here is the string name of a payment method ('cash'), not an "
            "amount — it is deliberately absent from the currency list, and is the kind of column a "
            "positional read would happily fill with money."
        ),
    ),
    "storage_vault": Carry(
        mode=CARRY_TRANSFORM,
        natural_key=("slot_id",),
        drop=("src_class",),  # class of the world container it was stashed from; that object is on the old map
        transcode={"vinv": JSONB, "pinv": JSONB},
        notes=(
            "The one container that is NOT map-anchored: slots are keyed by uid, not by position, so a "
            "vault carries whole. `vinv`/`pinv` are in the column family whose decode failures have "
            "historically destroyed player property (§7.1) — these get round-trip assertions first."
        ),
    ),
    # -- vehicles ---------------------------------------------------------------------
    "vehicles": Carry(
        mode=CARRY_TRANSFORM,
        natural_key=("id",),
        transcode={"inventory": JSONB, "mods": JSONB},
        booleans=("alive", "active", "listed", "alarm"),
        force={"active": False, "alive": True, "listed": False},
        notes=(
            "Vehicles carry because a garaged row is non-spatial — it has no worldspace at all. `active` is "
            "forced false so nothing is resurrected into a world position that no longer exists; `alive` true "
            "so a vehicle destroyed in the last minutes of the old server is not deleted by the new one; "
            "`listed` false because the marketplace listing it refers to does not carry (see `exchange`). "
            "The forced values are bools, not 0/1: these columns are declared flags, and a forced int would "
            "reach the output as `0` where every other flag is `false`. "
            "Keep `id`: `players_global.keys` and the plate references point at these rows."
        ),
    ),
    "gang_vehicles": Carry(
        mode=CARRY_TRANSFORM,
        natural_key=("id",),
        transcode={"inventory": JSONB, "mods": JSONB},
        booleans=("active", "alarm"),
        force={"active": False},
        notes=(
            "Same rule as `vehicles`, keyed to a gang instead of a player. The unique index on "
            "(gang_id, plate) may not exist on the source box — it is created by a statement whose result "
            "is discarded (plan §4.4) — so the load must not assume the source was unique; a duplicate "
            "(gang_id, plate) pair is an error to report, not a row to silently keep one of."
        ),
    ),
    "vehicle_mem": Carry(
        mode=DROP,
        natural_key=("id",),
        reason=(
            "MAP-ANCHORED: `worldspace` and `dir` are the only reason the table exists — it persists "
            "vehicles across a restart at the position they were left in. Those positions are on the old "
            "map. The vehicles themselves carry via `vehicles`, garaged."
        ),
        notes="No compensation source: nothing here is owned, it is a restart cache.",
    ),
    # -- property (destroyed by the map change) --------------------------------------
    "houses": Carry(
        mode=DROP,
        natural_key=("id", "oid"),
        reason=(
            "MAP-ANCHORED: `oid` is a rounded world-position hash and `worldspace` is old-map coordinates. "
            "There is no building on the new map that corresponds to a given building on the old one, so "
            "there is nothing to translate to."
        ),
        compensate="houses.compensation",
        notes=(
            "This is the single largest player-visible loss in the carry-over. The rows also hold "
            "`vinv`/`pinv`/`keyholders` — stored property, and the exact columns whose decode failures have "
            "destroyed player items before (§7.1) — plus `furniture`, upgrades (`barrel`, `greenhouse`, "
            "`leadcontainer`, `helipad`, capacity buys) and `custom_name`. Whatever compensation is chosen, "
            "it is valued from a row that is about to stop existing, so the valuation happens HERE, before "
            "the drop, and is written to the credit ledger. See COMPENSATION_SOURCES."
        ),
    ),
    "storage": Carry(
        mode=DROP,
        natural_key=("id",),
        reason=(
            "MAP-ANCHORED: `worldspace` and `houseworldspace` place a container in a specific building on "
            "the old map, and `houseid` references `houses`, which does not carry either."
        ),
        compensate="storage.compensation",
        notes=(
            "`contents` and `virtual` are stored player property. Losing the container is forced by the map "
            "change; losing what was inside it is what the compensation policy has to answer for. If the "
            "chosen policy is a conversion rather than a credit, `storage_vault` is the non-spatial "
            "destination that already exists."
        ),
    ),
    "suites": Carry(
        mode=DROP,
        natural_key=("id", "oid"),
        reason=(
            "MAP-ANCHORED: a suite is one floor of one tower instance, keyed `LUX<roundX><roundY>F<floor>`. "
            "The tower is map furniture at a fixed position; the key is literally a coordinate."
        ),
        compensate="suites.compensation",
        notes=(
            "Leases are rent-bearing, so the compensation basis differs from `houses`: a lease paid up to "
            "`next_due` has unconsumed rent in it, and an overdue one does not. `vinv`/`pinv`/`furniture` "
            "hold stored property, same family as houses."
        ),
    ),
    "house_rigs": Carry(
        mode=DROP,
        natural_key=("id",),
        reason=(
            "MAP-ANCHORED: `pos` is a world position inside a house that does not carry, and `oid` "
            "references `houses`."
        ),
        compensate="house_rigs.compensation",
        notes=(
            "Rigs were bought and accrue over time. Do NOT value a rig from accrued-but-uncollected yield: "
            "the source data is known-corrupt (sql/mining.sql documents live rows where a bug froze "
            "`last_collect` and re-minted the capped payout on every collect). Value the placement, not the "
            "accrual — the same conclusion the live multi-rig migration reached."
        ),
    ),
    "atm_skimmers": Carry(
        mode=DROP,
        natural_key=("atm_key",),
        reason=(
            "MAP-ANCHORED: `atm_key` is `round(posX)_round(posY)` of a world object on the old map."
        ),
        compensate="atm_skimmers.compensation",
        notes=(
            "A deployable that earns its owner a cut. Registered as a compensation source so the policy can "
            "answer for it explicitly — returning 0 from the policy is a decision; having no source at all "
            "would be an oversight."
        ),
    ),
    # -- gangs -----------------------------------------------------------------------
    "gangs": Carry(
        mode=CARRY_TRANSFORM,
        natural_key=("id",),
        drop=(
            "house_pos",  # MAP-ANCHORED: the gang base plot on the old map
            "instance",   # old deployment's instance id
        ),
        transcode={"wars": JSONB, "talents": JSONB},
        currency=("bank",),
        scaled=("bank",),
        notes=(
            "Identity, membership, bank and talents carry; the plot does not. `id` is preserved rather than "
            "regenerated because `players.gang0`, `gang_vehicles.gang_id`, `wars`, and every gang reference "
            "in the estate are keyed to it — and because gang ids are allocated on the source by "
            "`SELECT MAX(id)+1` (plan §7.2), so the target's identity sequence must be set past the highest "
            "carried id or the first new gang collides with a carried one."
        ),
    ),
    "wars": Carry(
        mode=CARRY_AS_IS,
        natural_key=("id",),
        notes="Gang-vs-gang war pairs. Carries because `gangs.id` is preserved. Non-spatial.",
    ),
    "gang_bank_log": Carry(
        mode=DROP,
        natural_key=("id",),
        reason=(
            "An audit ledger of the OLD economy. If BALANCE_SCALE is anything but 1:1 the carried balances "
            "no longer add up to the carried ledger, so the log would document a history that never "
            "happened. Dropping it is honest; rescaling it would be fabrication."
        ),
        notes=(
            "If the decision is 1:1 this could become CARRY_AS_IS with one line — that is exactly the kind "
            "of change this file exists to make visible."
        ),
    ),
    "gangfort": Carry(
        mode=DROP,
        natural_key=("id",),
        reason=(
            "In-flight state of a timed world event (`active`, `ends`, `leaderboard`) fought over a "
            "map location. The event does not survive the map change."
        ),
    ),
    "turf": Carry(
        mode=DROP,
        natural_key=("id",),
        reason="MAP-ANCHORED: turf ids index zones on the old map.",
    ),
    "turf_state": Carry(
        mode=DROP,
        natural_key=("id",),
        reason="MAP-ANCHORED: which turf zone is currently active, plus its timer.",
    ),
    "cartel_state": Carry(
        mode=DROP,
        natural_key=("cartel",),
        reason="MAP-ANCHORED: cartel ownership and capture progress, keyed to flag objects on the old map.",
    ),
    "captures": Carry(
        mode=DROP,
        natural_key=("id",),
        reason="MAP-ANCHORED: capture-point ownership and progress, keyed to points on the old map.",
    ),
    # -- law -------------------------------------------------------------------------
    "bans": Carry(
        mode=CARRY_AS_IS,
        natural_key=("id",),
        notes=(
            "Bans carry. This one is not a balance question: a ban that lapses because of a map change is a "
            "banned player back on day one, and the ban gate is documented as deliberately fail-open, so "
            "nothing downstream will catch it."
        ),
    ),
    "opfor_whitelist": Carry(
        mode=CARRY_AS_IS,
        natural_key=("playerid",),
        notes="Faction whitelist — a permission, like the level columns in players_global.",
    ),
    "wanted": Carry(
        mode=CARRY_TRANSFORM,
        natural_key=("playerid",),
        reason=(
            "DECISIONS.md #1, answered 2026-08-15: wanted levels and bounties carry. A player keeps the "
            "record they earned; the alternative was a general amnesty and the owner chose against it."
        ),
        transcode={"crimes": "jsonb"},
        currency=("bounty",),
        notes=(
            "`crimes` is a JSON array of charge counts indexed by charge id. `bounty` is currency and is "
            "therefore subject to decision 3, which is 1:1 -- so the value carries unchanged, but it goes "
            "through scale_currency like every other currency column so a later factor change cannot miss it."
        ),
    ),
    "bounties": Carry(
        mode=CARRY_AS_IS,
        natural_key=("id",),
        reason=(
            "DECISIONS.md #1, answered 2026-08-15: bounties carry, consistent with `wanted`. Somebody paid "
            "for these, so lapsing them would have been a confiscation; carrying them keeps the contract."
        ),
        currency=("amount",),
        notes="`amount` is bigint currency, scaled by decision 3 (1:1) like every other currency column.",
    ),
    # -- economy and the marketplace ---------------------------------------------------
    "exchange": Carry(
        mode=CARRY_TRANSFORM,
        natural_key=("ID",),
        rewrite="exchange.return_to_seller",
        booleans=(),
        currency=("Price",),
        scaled=("Price",),
        reason=(
            "DECISIONS.md #4, answered 2026-08-15: every open listing goes back to its seller. The table "
            "carries so that it can — an open listing holds goods the seller no longer has in inventory, "
            "so dropping the table confiscates them."
        ),
        notes=(
            "The rewrite mirrors the game's own retract path (exchangeSystemSRV mode 4) rather than "
            "inventing a migration-only rule: open item listings become Exchange Storage rows the seller "
            "withdraws, open vehicle listings drop because `vehicles` already forces `listed = False` and "
            "the car is back in the garage. `active = 2` rows are NOT open listings — they are goods "
            "already bought or retracted and awaiting collection, and they carry untouched. "
            "`Price` is scaled with every other currency column so a listing's asking price stays in "
            "proportion if the factor is ever not 1:1; at 1:1 it is unchanged. "
            "The old worldspace-free columns (`timer`, `bought_at`) carry as-is: they are clocks, and the "
            "7-day expiry sweep on the new server will age them out normally."
        ),
    ),
    "sportsbook_bets": Carry(
        mode=DROP,
        natural_key=("id",),
        reason=(
            "DECISIONS.md #5, answered 2026-08-15: open bets are void with no refund. The events they were "
            "placed on never resolve, and the owner chose the sportsbook as a sink rather than settling "
            "against odds for a fixture that did not happen."
        ),
        notes=(
            "This is the ONE decision in the set that takes money from players without compensation. It "
            "needs announcing before the freeze; unannounced it is the thing players will be angriest about."
        ),
    ),
    "itemstock": Carry(
        mode=DROP,
        natural_key=("className",),
        reason=(
            "Dynamic stock levels and sales counters of the OLD economy. The new economy sets its own "
            "starting stock; importing the old one imports its shortages and its price pressure."
        ),
    ),
    "price_overrides": Carry(
        mode=DROP,
        natural_key=("family", "item_key"),
        reason=(
            "Admin price overrides tuned against the old economy's prices and the old map's travel times. "
            "Carrying them silently overrides the new economy's pricing with the old one's judgement calls."
        ),
        notes="Keep the dump: these are worth READING when tuning the new prices, just not loading.",
    ),
    "refund_log": Carry(
        mode=DROP,
        natural_key=("playerid",),
        reason="Operational ledger of refunds already paid on the source box. History, not state.",
    ),
    # -- government ---------------------------------------------------------------------
    "gov_state": Carry(
        mode=DROP,
        natural_key=("id",),
        reason=(
            "The elected government's term, tax rate and policy flags belong to the old world's election. "
            "The new world starts ungoverned rather than inheriting a governor elected by a different map's "
            "playerbase."
        ),
        notes="If the owner wants continuity of office instead, this is a DECIDE, not a DROP. It is recorded as a drop because nobody has asked for continuity.",
    ),
    "candidates": Carry(
        mode=DROP,
        natural_key=("playerid",),
        reason=(
            "Candidacies in an election that ends with the old map. `investment` is money already spent on "
            "campaigning — flag it to the compensation decision if the freeze lands mid-campaign."
        ),
        notes=(
            "Deliberately NOT registered as a compensation source: campaign spend is consumed, not owned. "
            "If the owner disagrees, add a source rather than changing the mode."
        ),
    ),
    "votes": Carry(
        mode=DROP,
        natural_key=("id",),
        reason="Ballots cast in an election that does not carry.",
    ),
    # -- social ------------------------------------------------------------------------
    "looner_posts": Carry(
        mode=CARRY_AS_IS,
        natural_key=("id",),
        notes=(
            "The in-game microblog. Non-spatial, and a player's post history is theirs. The content refers "
            "to a world that no longer exists, which is an argument for a clean timeline — if the owner "
            "wants one, flip this and `looner_likes` to DROP together; likes reference `post_id`, so they "
            "cannot be split."
        ),
    ),
    "looner_likes": Carry(
        mode=CARRY_AS_IS,
        natural_key=("uid", "post_id"),
        notes="Carries with `looner_posts` or drops with it. Never one without the other.",
    ),
    "foreskins": Carry(
        mode=CARRY_AS_IS,
        natural_key=("uid",),
        notes="A first-time trophy record — an achievement by another name, so it carries with achievements.",
    ),
    "bones_dm": Carry(
        mode=DROP,
        natural_key=("id",),
        reason=(
            "A message queue between the game and an out-of-band daemon: undelivered rows are in-flight "
            "work for a process that will not be listening on the new box."
        ),
    ),
    "mentor_notify": Carry(
        mode=DROP,
        natural_key=("id",),
        reason="Queued in-game notifications. In-flight session state at the freeze instant.",
    ),
    # -- operational (belongs to the source box, not to players) ------------------------
    "log": Carry(
        mode=DROP,
        natural_key=("id",),
        reason=(
            "The action log of the old server — over a million rows describing a world that no longer "
            "exists. Keep the dump for forensics; do not load it."
        ),
    ),
    "restart_log": Carry(
        mode=DROP,
        natural_key=("id",),
        reason="Restart history of the source box.",
    ),
    "online": Carry(
        mode=DROP,
        natural_key=("playerid", "instance"),
        reason=(
            "Who was connected at the freeze instant. Transient by definition, and carrying it would mark "
            "players online on a server they have never joined — which the out-of-band consumers use as a "
            "safety check before writing."
        ),
    ),
    "server_control": Carry(
        mode=DROP,
        natural_key=("id",),
        reason=(
            "The control plane of the source box: pending restarts, watchdog windows, event flags. It is "
            "written by several OS-level processes that are not moving."
        ),
    ),
    "config": Carry(
        mode=DROP,
        natural_key=("index",),
        reason="Server configuration of the old deployment. The new server owns its own configuration.",
    ),
    "bot_commands": Carry(
        mode=DROP,
        natural_key=("id",),
        reason=(
            "A command queue polled by an out-of-band process. Pending rows are in-flight instructions "
            "aimed at the source box; carrying them would execute stale commands against new data."
        ),
    ),
    "discord_links": Carry(
        mode=CARRY_TRANSFORM,
        natural_key=("discord_id",),
        booleans=("beta_pending",),
        notes=(
            "Account links carry — they are identity, and re-linking every player by hand is not a "
            "migration plan. `reward_pending` is tinyint(4) used as a count/flag and is deliberately NOT "
            "in `booleans`: a pending reward that silently becomes `true` is a payout. "
            "The transform is boolean typing only; no columns are dropped."
        ),
    ),

    # -- found in the DEV DUMP on 2026-08-15, absent from the original enumeration ----
    #
    # plan §2 counted 49 tables from the repo's own SQL. A real dev dump has 52, and
    # eight of them were unknown here. That is not a defect in the count; it is the
    # reason `validate()` treats an unlisted table as an ERROR rather than a skip —
    # the repo does not know its own full schema, and the only thing that does is a
    # dump. RE-RUN THIS CHECK AGAINST A LIVE DUMP BEFORE THE FREEZE: live is a
    # different box with a different history and will have its own surprises.

    "casino_chips": Carry(
        mode=CARRY_TRANSFORM,
        natural_key=("pid", "chip"),
        drop=("updated_at",),
        notes=(
            "The powerup-chip wallet for DEALERBOT's table (APS_fnc_bjChips). `qty` is an ITEM "
            "count, not currency — chips are named powerups (brick, cascade, firewall), not a "
            "denomination — so it is deliberately not declared currency and not scaled. They carry "
            "because the casino exists on the new map and a chip is something the player earned. "
            "`updated_at` is a source clock the target sets itself."
        ),
    ),
    "casino_chip_pity": Carry(
        mode=CARRY_TRANSFORM,
        natural_key=("pid",),
        drop=("updated_at",),
        notes=(
            "Dry-win counter behind the chip drop's pity timer. Carried because dropping it silently "
            "takes back every near-miss a player has banked toward their next drop, which is a "
            "confiscation nobody would ever see in a report."
        ),
    ),
    "maxsec_applications": Carry(
        mode=CARRY_AS_IS,
        natural_key=("id",),
        notes=(
            "MaxSec (police) applications and their decisions, written by the Discord bot. Neither "
            "map-anchored nor gameplay state: it is the record of who was vetted and by whom. "
            "Dropping it means re-vetting 45 people and losing every decision note. "
            "`status` is an enum; ddl maps it to text + CHECK."
        ),
    ),
    "offline_msgs": Carry(
        mode=CARRY_TRANSFORM,
        natural_key=("id",),
        booleans=("delivered",),
        notes=(
            "Player-to-player messages awaiting delivery. Text, addressed to a uid, not anchored to "
            "anything that changes. Undelivered rows are somebody's unread message, so they carry. "
            "`delivered` holds only 0/1 on the dev box (checked) and is a real flag."
        ),
    ),
    "houses_malden": Carry(
        mode=DROP,
        natural_key=("id",),
        reason=(
            "A houses table keyed to Malden worldspace. MAP-ANCHORED by construction, and the "
            "carried property answer is already `houses` — two house tables crossing would double "
            "every owner's refund. Empty on the dev box, which is not why it drops."
        ),
    ),
    "radio_schedule": Carry(
        mode=DROP,
        natural_key=("station", "idx"),
        reason=(
            "Station playlist ordering — server configuration the new deployment generates for "
            "itself, not player data. Nobody owns a row in it."
        ),
    ),
    "enrique_log": Carry(
        mode=DROP,
        natural_key=("id",),
        reason=(
            "An event log for the Enrique weed-harvest bot. Logs do not carry, for the same reason "
            "`log` does not: it is a record of things that happened on a server that will not exist."
        ),
    ),
    "_backup_stats_declobber_462": Carry(
        mode=DROP,
        target_exists=False,
        natural_key=("id",),
        reason=(
            "A hand-made backup table from the stat/title corruption repair — a repair artefact that "
            "happens to live in the schema, not part of it. Carrying it would migrate a snapshot of "
            "damaged rows into the new database alongside the good ones. "
            "It is also the clearest argument for the unlisted-table error: a table named like this "
            "is exactly what a blanket 'carry everything' rule would have brought across."
        ),
    ),

    # -- found in the LIVE schema on 2026-08-15 -------------------------------------
    #
    # The dev box has 52 tables, live has 67, and the policy knew 46. Rehearsing
    # against dev found eight of the gap; reading the LIVE information_schema found
    # the rest. Live is the freeze source, so live is the schema that decides —
    # DEV IS NOT A VALID REHEARSAL SOURCE. It is the fork's own database and has
    # already been renamed forward (`ismaxtac`/`isscd`), which is why it fails a
    # policy that is correct for live.

    "apd_applications": Carry(
        mode=CARRY_AS_IS,
        natural_key=("id",),
        target_table="maxsec_applications",
        notes=(
            "THE SAME TABLE UNDER BOTH NAMES: the faction sweep renamed APD -> MaxSec, and the "
            "column sets are identical (checked against both boxes 2026-08-15). 75 real "
            "applications on live. Without the table rename they carry into a table the fork's "
            "Discord bot never reads, and the roster arrives empty with no error."
        ),
    ),
    "clankr_alerts": Carry(
        mode=DROP,
        natural_key=("id",),
        reason=(
            "Anti-cheat DETECTIONS (624 rows) against a world that will not exist — positions, "
            "distances and item counts on the old map, most of which cannot even be interpreted "
            "on the new one. The enforcement they produced does carry: `bans` is a carried table. "
            "This is the raw log behind it, and logs do not carry."
        ),
    ),
    '_backup_deck_talents': Carry(
        mode=DROP,
        target_exists=False,
        natural_key=("id",),
        reason=(
            "A hand-made backup table from a repair — a repair artefact living in the schema, not "
            "part of it. Carrying it would migrate a snapshot of pre-repair rows alongside the "
            "repaired ones. Six of these on live; every one drops."
        ),
    ),
    '_backup_rigs_multirig': Carry(
        mode=DROP,
        target_exists=False,
        natural_key=("id",),
        reason=(
            "A hand-made backup table from a repair — a repair artefact living in the schema, not "
            "part of it. Carrying it would migrate a snapshot of pre-repair rows alongside the "
            "repaired ones. Six of these on live; every one drops."
        ),
    ),
    '_backup_shed_683': Carry(
        mode=DROP,
        target_exists=False,
        natural_key=("id",),
        reason=(
            "A hand-made backup table from a repair — a repair artefact living in the schema, not "
            "part of it. Carrying it would migrate a snapshot of pre-repair rows alongside the "
            "repaired ones. Six of these on live; every one drops."
        ),
    ),
    '_backup_shed_uderelict': Carry(
        mode=DROP,
        target_exists=False,
        natural_key=("id",),
        reason=(
            "A hand-made backup table from a repair — a repair artefact living in the schema, not "
            "part of it. Carrying it would migrate a snapshot of pre-repair rows alongside the "
            "repaired ones. Six of these on live; every one drops."
        ),
    ),
    '_backup_talent_wipe_b0097': Carry(
        mode=DROP,
        target_exists=False,
        natural_key=("id",),
        reason=(
            "A hand-made backup table from a repair — a repair artefact living in the schema, not "
            "part of it. Carrying it would migrate a snapshot of pre-repair rows alongside the "
            "repaired ones. Six of these on live; every one drops."
        ),
    ),
    '_backup_vtol_swap_20260705': Carry(
        mode=DROP,
        target_exists=False,
        natural_key=("id",),
        reason=(
            "A hand-made backup table from a repair — a repair artefact living in the schema, not "
            "part of it. Carrying it would migrate a snapshot of pre-repair rows alongside the "
            "repaired ones. Six of these on live; every one drops."
        ),
    ),
    'web_admin_log': Carry(
        mode=DROP,
        target_exists=False,
        natural_key=("id",),
        reason=(
            "WEBSITE DATA, and out of scope by plan §8: \"the frozen box keeps MariaDB, and its "
            "website, bots and deploy scripts keep working against it, untouched.\" The portal is "
            "not migrating with the game, so its tables are not part of the carry-over. If the "
            "website is ever pointed at the new database, this is a decision to revisit — with a "
            "dated line in DECISIONS.md, not a quiet edit here."
        ),
    ),
    'web_changelogs': Carry(
        mode=DROP,
        target_exists=False,
        natural_key=("id",),
        reason=(
            "WEBSITE DATA, and out of scope by plan §8: \"the frozen box keeps MariaDB, and its "
            "website, bots and deploy scripts keep working against it, untouched.\" The portal is "
            "not migrating with the game, so its tables are not part of the carry-over. If the "
            "website is ever pointed at the new database, this is a decision to revisit — with a "
            "dated line in DECISIONS.md, not a quiet edit here."
        ),
    ),
    'web_faction_blacklist': Carry(
        mode=DROP,
        target_exists=False,
        natural_key=("id",),
        reason=(
            "WEBSITE DATA, and out of scope by plan §8: \"the frozen box keeps MariaDB, and its "
            "website, bots and deploy scripts keep working against it, untouched.\" The portal is "
            "not migrating with the game, so its tables are not part of the carry-over. If the "
            "website is ever pointed at the new database, this is a decision to revisit — with a "
            "dated line in DECISIONS.md, not a quiet edit here."
        ),
    ),
    'web_feature_comments': Carry(
        mode=DROP,
        target_exists=False,
        natural_key=("id",),
        reason=(
            "WEBSITE DATA, and out of scope by plan §8: \"the frozen box keeps MariaDB, and its "
            "website, bots and deploy scripts keep working against it, untouched.\" The portal is "
            "not migrating with the game, so its tables are not part of the carry-over. If the "
            "website is ever pointed at the new database, this is a decision to revisit — with a "
            "dated line in DECISIONS.md, not a quiet edit here."
        ),
    ),
    'web_feature_requests': Carry(
        mode=DROP,
        target_exists=False,
        natural_key=("id",),
        reason=(
            "WEBSITE DATA, and out of scope by plan §8: \"the frozen box keeps MariaDB, and its "
            "website, bots and deploy scripts keep working against it, untouched.\" The portal is "
            "not migrating with the game, so its tables are not part of the carry-over. If the "
            "website is ever pointed at the new database, this is a decision to revisit — with a "
            "dated line in DECISIONS.md, not a quiet edit here."
        ),
    ),
    'web_feature_votes': Carry(
        mode=DROP,
        target_exists=False,
        natural_key=("id",),
        reason=(
            "WEBSITE DATA, and out of scope by plan §8: \"the frozen box keeps MariaDB, and its "
            "website, bots and deploy scripts keep working against it, untouched.\" The portal is "
            "not migrating with the game, so its tables are not part of the carry-over. If the "
            "website is ever pointed at the new database, this is a decision to revisit — with a "
            "dated line in DECISIONS.md, not a quiet edit here."
        ),
    ),
    'web_ticket_messages': Carry(
        mode=DROP,
        target_exists=False,
        natural_key=("id",),
        reason=(
            "WEBSITE DATA, and out of scope by plan §8: \"the frozen box keeps MariaDB, and its "
            "website, bots and deploy scripts keep working against it, untouched.\" The portal is "
            "not migrating with the game, so its tables are not part of the carry-over. If the "
            "website is ever pointed at the new database, this is a decision to revisit — with a "
            "dated line in DECISIONS.md, not a quiet edit here."
        ),
    ),
    'web_tickets': Carry(
        mode=DROP,
        target_exists=False,
        natural_key=("id",),
        reason=(
            "WEBSITE DATA, and out of scope by plan §8: \"the frozen box keeps MariaDB, and its "
            "website, bots and deploy scripts keep working against it, untouched.\" The portal is "
            "not migrating with the game, so its tables are not part of the carry-over. If the "
            "website is ever pointed at the new database, this is a decision to revisit — with a "
            "dated line in DECISIONS.md, not a quiet edit here."
        ),
    ),
    'web_vpn_exempt': Carry(
        mode=DROP,
        target_exists=False,
        natural_key=("id",),
        reason=(
            "WEBSITE DATA, and out of scope by plan §8: \"the frozen box keeps MariaDB, and its "
            "website, bots and deploy scripts keep working against it, untouched.\" The portal is "
            "not migrating with the game, so its tables are not part of the carry-over. If the "
            "website is ever pointed at the new database, this is a decision to revisit — with a "
            "dated line in DECISIONS.md, not a quiet edit here."
        ),
    ),
    'web_whitelist_log': Carry(
        mode=DROP,
        target_exists=False,
        natural_key=("id",),
        reason=(
            "WEBSITE DATA, and out of scope by plan §8: \"the frozen box keeps MariaDB, and its "
            "website, bots and deploy scripts keep working against it, untouched.\" The portal is "
            "not migrating with the game, so its tables are not part of the carry-over. If the "
            "website is ever pointed at the new database, this is a decision to revisit — with a "
            "dated line in DECISIONS.md, not a quiet edit here."
        ),
    ),
    'web_wiki_pages': Carry(
        mode=DROP,
        target_exists=False,
        natural_key=("id",),
        reason=(
            "WEBSITE DATA, and out of scope by plan §8: \"the frozen box keeps MariaDB, and its "
            "website, bots and deploy scripts keep working against it, untouched.\" The portal is "
            "not migrating with the game, so its tables are not part of the carry-over. If the "
            "website is ever pointed at the new database, this is a decision to revisit — with a "
            "dated line in DECISIONS.md, not a quiet edit here."
        ),
    ),
}

#: Name used by README.md and DECISIONS.md for the same object.
CARRY_POLICY = CARRY


# ---------------------------------------------------------------------------
# Row rewrites — transforms that depend on the row, not just the column
# ---------------------------------------------------------------------------


def _exchange_return_to_seller(row: MutableMapping[str, object]) -> MutableMapping[str, object]:
    """Return every OPEN exchange listing to the player who listed it.

    DECISIONS.md #4, answered 2026-08-15. This is not a bespoke rule invented for
    the migration: it is exactly what the game already does when a player retracts
    their own listing (`APS_fnc_exchangeSystemSRV` mode 4), applied to every open
    listing at once because the freeze retracts them all.

        active=1, isVehicle=1  the vehicle row itself is the goods. `vehicles`
                               already forces `listed = False`, so the car is back
                               in its owner's garage with nothing to do here; the
                               listing row is dropped (mode 4 DELETEs it).
        active=1, otherwise    becomes an Exchange Storage row — active=2,
                               BuyorSell=2 (retracted) — which the seller withdraws
                               from the Exchange on the new map.
        active=2               ALREADY storage: goods bought or previously retracted
                               and not yet collected. Carried untouched. These are
                               the rows it would be easiest to destroy by mistake,
                               and they are somebody's paid-for property.

    Returning `None` drops the row.
    """
    active = _as_int(row.get("active"))
    if active != 1:
        return row                      # storage rows carry exactly as they are
    if _as_int(row.get("isVehicle")) == 1:
        return None                     # the vehicle carries; the listing does not
    row["active"] = 2
    row["BuyorSell"] = 2
    return row


def _as_int(value: object) -> int:
    """Loose int read for a flag column that may arrive as int, str or bool.

    Deliberately loose: `active` is tinyint in the source and arrives as `1`,
    `"1"` or `True` depending on which dump path produced it, and a strict read
    would classify a listing as storage on a formatting difference.
    """
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return -1


#: rewrite name -> fn(row) -> row | None. Referenced by name from CARRY.
ROW_REWRITES: dict[str, Callable[[MutableMapping[str, object]], object]] = {
    "exchange.return_to_seller": _exchange_return_to_seller,
}


# ---------------------------------------------------------------------------
# Compensation — mechanism here, policy deliberately absent
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class CompensationSource:
    """One dropped table whose rows represent something a player paid for.

    `owner_column` is where the credited player's uid lives; `basis_columns` is
    what a valuation may legitimately look at, recorded so a reviewer can see
    what information the policy has to work with.
    """

    name: str
    table: str
    owner_column: str
    basis_columns: tuple[str, ...]
    notes: str
    #: Optional extractor for an owner column that is not a bare uid. Fails loud
    #: rather than guessing when the stored form is unexpected.
    owner_parser: Callable[[object], str] | None = None


COMPENSATION_SOURCES: dict[str, CompensationSource] = {
    "houses.compensation": CompensationSource(
        name="houses.compensation",
        table="houses",
        owner_column="owners",
        basis_columns=(
            "oid", "classname", "sale", "vcap", "phys_cap", "keycap",
            "barrel", "greenhouse", "leadcontainer", "furniture", "vinv", "pinv",
        ),
        notes=(
            "`sale` is the sale price, which is the closest thing to a purchase price the row holds — it "
            "is not necessarily what this player paid. `classname` identifies the building type, which is "
            "what a market-value policy would price. Upgrades were bought separately and are visible as "
            "flags/caps; a policy that ignores them refunds less than the player spent."
        ),
    ),
    "storage.compensation": CompensationSource(
        name="storage.compensation",
        table="storage",
        owner_column="houseid",
        basis_columns=("classname", "contents", "virtual", "container"),
        notes=(
            "NOTE: `storage` has no owner column — it is keyed to `houseid`. The credit therefore has to be "
            "resolved through the (also dropped) houses row, which means an owner_parser that is given the "
            "house id and cannot resolve it alone. This is left explicit rather than papered over: whoever "
            "implements the policy must supply the houseid -> owner map from the same dump, and the "
            "mechanism will raise until they do."
        ),
    ),
    "suites.compensation": CompensationSource(
        name="suites.compensation",
        table="suites",
        owner_column="owner",
        basis_columns=("floor", "leased_at", "next_due", "overdue_since", "vinv", "pinv", "furniture"),
        notes=(
            "A lease, not a freehold: `next_due` minus the freeze instant is unconsumed rent, and "
            "`overdue_since` non-zero means the player already owed money. A vacant row has `owner` NULL "
            "and must produce no credit at all."
        ),
    ),
    "house_rigs.compensation": CompensationSource(
        name="house_rigs.compensation",
        table="house_rigs",
        owner_column="owner",
        basis_columns=("since",),
        notes=(
            "Value the placement, never the accrual. `last_collect` is known-corrupt on live for a large "
            "share of rows (sql/mining.sql), so any policy that pays out pending yield pays out a bug."
        ),
    ),
    "atm_skimmers.compensation": CompensationSource(
        name="atm_skimmers.compensation",
        table="atm_skimmers",
        owner_column="owner_uid",
        basis_columns=("applied_at",),
        notes=(
            "A deployable with no recorded price. A policy returning 0 here is entirely defensible — but it "
            "has to be written down as 0, not left out."
        ),
    ),
}


#: (source_name, row_values) -> exact integer credit in SOURCE currency units.
CompensationValuer = Callable[[str, Mapping[str, object]], int]

#: THE COMPENSATION POLICY. NO DEFAULT, DELIBERATELY. (DECISIONS.md #2)
#:
#: Owned property does not survive the map change. What replaces it — refund at
#: purchase price, refund at market value, a flat credit, or nothing — is a
#: product decision, and every option produces a different number for the same
#: player. A default would be this file choosing on the owner's behalf and then
#: being cited as if somebody had.
#:
#: Set it with set_compensation_policy(fn) where fn is
#:     (source_name: str, row: Mapping[str, object]) -> int
#: returning an EXACT INTEGER in source currency units. Returning 0 is a valid,
#: explicit answer. Returning a float is an error, not a rounding problem.
COMPENSATION_POLICY: CompensationValuer | _Undecided = UNDECIDED

#: Whether compensation is added before or after BALANCE_SCALE is applied.
#: The two orders give different numbers, so it is part of decision 2 and has no
#: default either.
BEFORE_SCALING = "before_scaling"
AFTER_SCALING = "after_scaling"
COMPENSATION_ORDER: str | _Undecided = UNDECIDED

#: WHERE PLAYER IDENTITY LIVES. One row per account, keyed by the platform uid —
#: the only identifier that survives a map change, a rename and a new deployment.
#: The auditor counts these one at a time rather than as a total (one player lost
#: plus one duplicated is a perfect draw in a count).
IDENTITY_TABLE = "players"
IDENTITY_COLUMN = "playerid"

#: WHERE THE CREDIT LANDS. A compensation credit is money, so it has to end up in
#: a currency column of a carried table, keyed to the player it belongs to. Bank
#: rather than cash: the credit is a payout for property, not something the player
#: was carrying when the world ended, and a bank balance is the one place a player
#: cannot lose it by dying on the first evening.
#:
#: Declared here rather than in the transform because it is policy — moving it to
#: `cash` is a decision somebody should have to make in this file, in a diff.
COMPENSATION_CREDIT_TABLE = IDENTITY_TABLE
COMPENSATION_CREDIT_COLUMN = "bankacc"
COMPENSATION_CREDIT_OWNER_COLUMN = IDENTITY_COLUMN


def compensation_tables() -> list[str]:
    """Source tables whose rows must be READ to value what the map change destroys.

    Every one of them is a DROP table, so nothing else in the run has any reason
    to parse them — which is exactly how compensation ends up structurally
    impossible rather than merely unimplemented: with these tables filtered out
    of the row stream, there is nothing to value.
    """
    return sorted(t for t, entry in CARRY.items() if entry.compensate)


@dataclass
class CompensationResult:
    """Per-player credits plus the counts reconciliation needs.

    `credits` is uid -> exact integer credit in source currency units.
    `per_source` and `rows_seen` exist so a run can be reconciled per source
    rather than as one opaque total: "houses paid out X across N rows" is
    auditable, "compensation paid out X" is not.
    """

    credits: dict[str, int] = field(default_factory=dict)
    per_source: dict[str, int] = field(default_factory=dict)
    rows_seen: dict[str, int] = field(default_factory=dict)
    rows_skipped_unowned: dict[str, int] = field(default_factory=dict)


def set_compensation_policy(policy: CompensationValuer) -> None:
    """Install the compensation valuation function. Callable, or it is an error."""
    global COMPENSATION_POLICY
    if not callable(policy):
        raise TypeError("compensation policy must be callable, got %r" % (type(policy),))
    COMPENSATION_POLICY = policy


def set_compensation_order(order: str) -> None:
    """Record whether compensation applies before or after balance scaling."""
    global COMPENSATION_ORDER
    if order not in (BEFORE_SCALING, AFTER_SCALING):
        raise ValueError("compensation order must be %r or %r, got %r" % (BEFORE_SCALING, AFTER_SCALING, order))
    COMPENSATION_ORDER = order


def _source_for_table(table: str) -> CompensationSource:
    entry = CARRY.get(table)
    if entry is None:
        raise TransformError(Issue("error", table, None, None,
                                   "no CARRY entry, so it has no compensation disposition either"))
    if not entry.compensate:
        raise TransformError(Issue("error", table, None, None,
                                   "table is not registered as a compensation source; "
                                   "dropped rows here are not compensated by policy"))
    source = COMPENSATION_SOURCES.get(entry.compensate)
    if source is None:
        raise TransformError(Issue("error", table, None, None,
                                   "CARRY names compensation source %r, which is not registered" % entry.compensate))
    return source


def _pk_of(table: str, values: Mapping[str, object]) -> object:
    """Best available row identity for an error message. Never a row number."""
    entry = CARRY.get(table)
    if entry is None or not entry.natural_key:
        return None
    parts = [values.get(col) for col in entry.natural_key]
    return parts[0] if len(parts) == 1 else tuple(parts)


def _owner_uid(source: CompensationSource, values: Mapping[str, object], pk: object) -> str | None:
    """Extract the credited player's uid, or None when the row is unowned.

    Fails loud on anything it cannot read. The one form that is known to vary is
    the house owner column: it is declared varchar(17) but the repo's own
    migration notes describe it as a nested-array string, and no dump has been
    seen here to settle which. Guessing at that would credit the wrong player or
    nobody — so an unrecognised form is an error naming the table, column and pk.
    """
    raw = values.get(source.owner_column, None)
    if source.owner_parser is not None:
        parsed = source.owner_parser(raw)
        if parsed is not None and not isinstance(parsed, str):
            raise TransformError(Issue("error", source.table, source.owner_column, pk,
                                       "owner_parser returned %r, expected a uid string or None" % (type(parsed),)))
        return parsed
    if raw is None or raw == "" or raw == "NULL":
        return None  # vacant lease / unowned row: no credit, and not an error
    if not isinstance(raw, str):
        raise TransformError(Issue("error", source.table, source.owner_column, pk,
                                   "owner value is %r, not text; supply an owner_parser for this source"
                                   % (type(raw),)))
    uid = raw.strip()
    if uid.isdigit() and 15 <= len(uid) <= 20:
        return uid
    raise TransformError(Issue("error", source.table, source.owner_column, pk,
                               "owner value %r is not a bare player uid (it may be the nested-array form); "
                               "supply an owner_parser for source %r rather than guessing"
                               % (raw[:64], source.name)))


def compute_compensation(rows: Iterable[Row], *, policy: CompensationValuer | None = None) -> CompensationResult:
    """Compute per-player credits from rows that are about to be dropped.

    THE MECHANISM IS HERE; THE POLICY IS NOT. `policy` (or the module-level
    COMPENSATION_POLICY) decides what a row is worth. This function decides who
    gets credited, that the number is an exact integer, and that nothing is
    silently skipped.

    Every row must belong to a table registered as a compensation source. A row
    from anywhere else is an error, not a zero — otherwise a table added upstream
    would quietly compensate nobody.

    Usage:
        >>> from model import Row
        >>> set_compensation_policy(lambda source, row: 0)   # doctest: +SKIP
        >>> result = compute_compensation(dropped_rows)      # doctest: +SKIP
        >>> result.credits["76561198000000000"]              # doctest: +SKIP
        250000
    """
    chosen = policy if policy is not None else COMPENSATION_POLICY
    if isinstance(chosen, _Undecided):
        raise TransformError(Issue(
            "error", "<compensation>", None, None,
            "COMPENSATION_POLICY is UNDECIDED. Property destroyed by the map change cannot be valued "
            "until a human answers DECISIONS.md #2 (purchase price / market value / flat credit / "
            "nothing). There is no default because a default would be a policy nobody chose."))
    if not callable(chosen):
        raise TransformError(Issue("error", "<compensation>", None, None,
                                   "COMPENSATION_POLICY is %r, which is not callable" % (type(chosen),)))

    result = CompensationResult()
    for row in rows:
        if not isinstance(row, Row):
            raise TransformError(Issue("error", "<compensation>", None, None,
                                       "compute_compensation takes model.Row objects, got %r" % (type(row),)))
        source = _source_for_table(row.table)
        pk = _pk_of(row.table, row.values)
        result.rows_seen[source.name] = result.rows_seen.get(source.name, 0) + 1

        uid = _owner_uid(source, row.values, pk)
        if uid is None:
            result.rows_skipped_unowned[source.name] = result.rows_skipped_unowned.get(source.name, 0) + 1
            continue

        credit = chosen(source.name, row.values)
        if isinstance(credit, bool) or not isinstance(credit, int):
            raise TransformError(Issue(
                "error", source.table, None, pk,
                "compensation policy returned %r for source %r; money is exact-integer end to end, so a "
                "credit must be an int (a float here silently rounds every large balance)"
                % (type(credit), source.name)))
        if credit < 0:
            raise TransformError(Issue("error", source.table, None, pk,
                                       "compensation policy returned a negative credit (%d) for source %r; "
                                       "compensation cannot take money away" % (credit, source.name)))
        result.credits[uid] = result.credits.get(uid, 0) + credit
        result.per_source[source.name] = result.per_source.get(source.name, 0) + credit
    return result


# ---------------------------------------------------------------------------
# Balance scaling — mechanism here, the factor is a decision
# ---------------------------------------------------------------------------

#: THE BALANCE SCALING FACTOR. Defaults to 1:1 — and 1:1 IS A DECISION.
#:
#: This project overhauls the economy. Carrying balances forward unchanged
#: imports the old economy's inflation into the new one, which is a choice with
#: consequences (every new price is calibrated against balances earned under old
#: prices). It is recorded here as an exact rational so that the factor can never
#: become a float: money is exact-integer end to end, and a float factor would
#: break that in the one place it matters most.
#:
#: Set it with set_balance_scale(Fraction(1, 2)) or set_balance_scale("0.1").
#: Never with a float literal — the setter refuses one on purpose.
BALANCE_SCALE: Fraction = Fraction(1, 1)

#: Confirmation that 1:1 was chosen rather than left unread. Scaling has a
#: working default so the mechanism is testable; the DECISION still has to be
#: made, and validate() refuses to pass while this is UNDECIDED.
BALANCE_SCALE_CONFIRMED: bool | _Undecided = UNDECIDED

#: Rounding direction, part of decision 3 — reconciliation checks totals against
#: it, so it cannot be left to the implementation. Only consulted when scaling is
#: not 1:1 (at 1:1 nothing rounds).
ROUND_FLOOR_MODE = "floor"
ROUND_HALF_UP_MODE = "half_up"
BALANCE_ROUNDING: str | _Undecided = UNDECIDED

#: Declared decimal scale of exact-decimal currency columns, so scaling quantizes
#: to the column and not to whatever the value happened to carry.
DECIMAL_SCALES: dict[tuple[str, str], int] = {
    ("players", "new_drachma"): 4,
}


def set_balance_scale(scale: Fraction | Decimal | int | str, *, rounding: str | None = None) -> None:
    """Record the balance scaling factor as an EXACT ratio. Floats are refused.

    A float factor is the same failure as a float balance: `0.1` is not 0.1, and
    the error compounds across every player. Pass a Fraction, a Decimal, an int,
    or a string that parses exactly ("0.1", "9/10").
    """
    global BALANCE_SCALE, BALANCE_SCALE_CONFIRMED, BALANCE_ROUNDING
    if isinstance(scale, float):
        raise TypeError("balance scale must be exact, never a float; pass Fraction(1, 10) or \"0.1\"")
    if isinstance(scale, Fraction):
        exact = scale
    elif isinstance(scale, int) and not isinstance(scale, bool):
        exact = Fraction(scale)
    elif isinstance(scale, Decimal):
        exact = Fraction(scale)
    elif isinstance(scale, str):
        exact = Fraction(scale)  # accepts "0.1" and "9/10"; raises on anything else
    else:
        raise TypeError("balance scale must be Fraction, Decimal, int or str, got %r" % (type(scale),))
    if exact <= 0:
        raise ValueError("balance scale must be positive, got %s" % exact)
    if rounding is not None:
        if rounding not in (ROUND_FLOOR_MODE, ROUND_HALF_UP_MODE):
            raise ValueError("rounding must be %r or %r" % (ROUND_FLOOR_MODE, ROUND_HALF_UP_MODE))
        BALANCE_ROUNDING = rounding
    BALANCE_SCALE = exact
    BALANCE_SCALE_CONFIRMED = True


def scale_currency(table: str, column: str, pk: object, value: object,
                   *, scale: Fraction | None = None) -> int | Decimal:
    """Apply the balance scale to one currency value, exactly.

    Integers stay integers, exact decimals stay exact decimals at the column's
    declared scale, and a float anywhere in the input is an error rather than a
    conversion. At 1:1 this is the identity function, which is asserted by test —
    the no-scaling case must not be able to perturb a balance.
    """
    factor = BALANCE_SCALE if scale is None else scale
    if isinstance(factor, float):
        raise TransformError(Issue("error", table, column, pk,
                                   "balance scale is a float; money is exact-integer end to end"))

    if isinstance(value, bool):
        raise TransformError(Issue("error", table, column, pk, "currency value is a bool"))
    if isinstance(value, float):
        raise TransformError(Issue(
            "error", table, column, pk,
            "currency value arrived as a float; balances above 16,777,216 are already wrong by the time "
            "they get here. Carry currency as int/Decimal from parse to emit (plan §7.3)"))

    is_decimal_column = (table, column) in DECIMAL_SCALES
    if isinstance(value, int):
        exact = Fraction(value)
    elif isinstance(value, Decimal):
        exact = Fraction(value)
        is_decimal_column = True
    elif isinstance(value, str):
        text = value.strip()
        try:
            exact = Fraction(Decimal(text))
        except Exception as exc:  # noqa: BLE001 - re-raised as a located TransformError below
            raise TransformError(Issue("error", table, column, pk,
                                       "currency value %r does not parse exactly (%s)" % (value[:64], exc))) from exc
        if "." in text:
            is_decimal_column = True
    else:
        raise TransformError(Issue("error", table, column, pk,
                                   "currency value is %r; expected int, Decimal or exact numeric text"
                                   % (type(value),)))

    scaled = exact * Fraction(factor)

    if is_decimal_column:
        places = DECIMAL_SCALES.get((table, column))
        if places is None:
            raise TransformError(Issue(
                "error", table, column, pk,
                "exact-decimal currency with no declared scale; add (table, column) to DECIMAL_SCALES "
                "rather than letting the value pick its own precision"))
        return _exact_decimal(table, column, pk, scaled, places)

    if scaled.denominator == 1:
        return int(scaled)
    return _round_exact(table, column, pk, scaled)


def _rounding_mode(table: str, column: str, pk: object) -> str:
    if isinstance(BALANCE_ROUNDING, _Undecided):
        raise TransformError(Issue(
            "error", table, column, pk,
            "BALANCE_ROUNDING is UNDECIDED and this value does not scale to a whole unit. The rounding "
            "direction is part of DECISIONS.md #3 because reconciliation checks totals against it."))
    return BALANCE_ROUNDING


def _round_exact(table: str, column: str, pk: object, scaled: Fraction) -> int:
    """Round an exact rational to an integer, in the decided direction.

    Integer arithmetic throughout: no float ever touches a balance, and "half up"
    means floor(x + 1/2) — ties go toward +infinity, on both the integer and the
    decimal path, so the two cannot disagree when reconciliation adds them up.

    KNOWN DIVERGENCE: `reconcile.Scaling.apply` rounds a half AWAY FROM ZERO, so
    on a NEGATIVE balance landing exactly on a half the two differ by one unit.
    Recorded in `reconcile_spec()` too. It cannot arise at 1:1 (nothing rounds)
    and needs settling before any run that combines a fractional scale with a
    negative balance.
    """
    mode = _rounding_mode(table, column, pk)
    if mode == ROUND_FLOOR_MODE:
        return scaled.numerator // scaled.denominator
    doubled = scaled * 2
    return (doubled.numerator + doubled.denominator) // (2 * doubled.denominator)


def _exact_decimal(table: str, column: str, pk: object, scaled: Fraction, places: int) -> Decimal:
    """Render an exact rational as a Decimal at the column's declared scale.

    Built from an integer and a string rather than by Decimal arithmetic: the
    default decimal context carries 28 significant digits, and a decimal(20,4)
    balance run through `/` or `scaleb` can silently lose the low digits — the
    same class of error as letting it become a float, arriving by a quieter road.
    """
    shifted = scaled * (10 ** places)
    units = shifted.numerator if shifted.denominator == 1 else _round_exact(table, column, pk, shifted)
    if places == 0:
        return Decimal(str(units))
    sign = "-" if units < 0 else ""
    digits = str(abs(units)).rjust(places + 1, "0")
    return Decimal("%s%s.%s" % (sign, digits[:-places], digits[-places:]))


def apply_compensation(*, table: str, column: str, pk: object, balance: object, credit: int) -> int | Decimal:
    """Combine a carried balance with a compensation credit, in the decided order.

    Refunding before or after scaling gives different numbers for the same
    player, so the order is part of the compensation decision and is refused
    until it is recorded (DECISIONS.md #2).
    """
    if isinstance(credit, bool) or not isinstance(credit, int):
        raise TransformError(Issue("error", table, column, pk,
                                   "compensation credit must be an exact int, got %r" % (type(credit),)))
    if isinstance(COMPENSATION_ORDER, _Undecided):
        raise TransformError(Issue(
            "error", table, column, pk,
            "COMPENSATION_ORDER is UNDECIDED: compensation applied before scaling and compensation applied "
            "after scaling produce different balances. Record which in DECISIONS.md #2."))
    if COMPENSATION_ORDER == BEFORE_SCALING:
        combined = _add_currency(table, column, pk, balance, credit)
        return scale_currency(table, column, pk, combined)
    scaled = scale_currency(table, column, pk, balance)
    return _add_currency(table, column, pk, scaled, credit)


def _add_currency(table: str, column: str, pk: object, value: object, credit: int) -> int | Decimal:
    if isinstance(value, bool) or isinstance(value, float):
        raise TransformError(Issue("error", table, column, pk, "cannot add a credit to a non-exact balance"))
    if isinstance(value, int):
        return value + credit
    if isinstance(value, Decimal):
        return value + Decimal(credit)
    if isinstance(value, str):
        return scale_currency(table, column, pk, value, scale=Fraction(1)) + credit  # type: ignore[operator]
    raise TransformError(Issue("error", table, column, pk,
                               "balance is %r; expected int, Decimal or exact numeric text" % (type(value),)))


# ---------------------------------------------------------------------------
# The freeze (DECISIONS.md #4) — recorded here because README points at it
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class Freeze:
    """When the final dump is taken and what players were told about it."""

    dump_taken_utc: str
    maintenance_window: bool
    announced_on: str


#: NO DEFAULT. The freeze is the only part of the plan players experience
#: directly: everything they do on the source server after this instant is lost.
FREEZE: Freeze | _Undecided = Freeze(
    dump_taken_utc="2026-09-08T00:59:40Z",   # looneybin_FINAL_20260907_195940.sql.gz; the server was stopped 00:57Z with 0 players on
    maintenance_window=True,                 # LooneyBin is down for good (MIGRATION_96.md §0): nothing after the dump can be lost
    announced_on="2026-09-07",               # owner cleared the plan 2026-09-07; the Discord post rides the [COMING SOON] announcement
)


def set_freeze(freeze: Freeze) -> None:
    """Record the freeze. A Freeze, or it is an error."""
    global FREEZE
    if not isinstance(freeze, Freeze):
        raise TypeError("set_freeze takes a Freeze, got %r" % (type(freeze),))
    FREEZE = freeze


# ---------------------------------------------------------------------------
# validate — the guard that makes silence impossible
# ---------------------------------------------------------------------------


def check(source_tables: Iterable[str], *,
          allow_unresolved_tables: bool = False,
          allow_undecided_policy: bool = False) -> list[Issue]:
    """Return every issue with the policy as applied to this dump. Never raises.

    Use this for the rehearsal loop and for reports; use validate() to gate a run.

    TWO WAIVERS, SEPARATELY, and they are not the same question:
      * `allow_unresolved_tables` — proceed with tables whose carry-over rule is
        still DECIDE. Their rows are not migrated.
      * `allow_undecided_policy` — proceed with the four GLOBAL decisions unmade
        (compensation policy, compensation order, balance-scale confirmation,
        freeze). This one means, among other things, that property destroyed by
        the map change is compensated at nothing.
    They used to be one flag, which meant a rehearsal switch named for the first
    silently granted the second — turning off every gate DECISIONS.md exists to
    force, while telling the operator it only skipped undecided tables.

    Errors:
      * a table in the dump with no CARRY entry — the silent-drop hole this
        module exists to close (never waivable);
      * any DECIDE entry still unresolved;
      * a DROP that registers compensation while COMPENSATION_POLICY is unset;
      * an unrecorded compensation order, balance-scale confirmation or freeze.
    Warnings:
      * a CARRY entry for a table the dump does not contain (schema drift, or a
        feature that never shipped to the source box).
    """
    issues: list[Issue] = []
    present = list(dict.fromkeys(source_tables))  # de-dupe, keep order
    known = set(CARRY)

    for table in present:
        if table not in known:
            issues.append(Issue(
                "error", table, None, None,
                "source table %r has no entry in CARRY, so nothing decides whether it carries. Add an "
                "explicit entry — carried or dropped, with a reason. An unlisted table is an error, not a "
                "skip: the repo does not know its own full schema (plan §2), so silence here is how a new "
                "table full of player data gets discarded without anyone noticing." % table))

    for table in sorted(known - set(present)):
        issues.append(Issue(
            "warn", table, None, None,
            "CARRY has an entry for %r but the dump does not contain it. Either the source box never had "
            "this table, or the dump is incomplete — a dump taken without --routines --triggers --events "
            "parses fine and is wrong." % table))

    if not allow_unresolved_tables:
        for table in present:
            entry = CARRY.get(table)
            if entry is not None and entry.mode == DECIDE:
                issues.append(Issue(
                    "error", table, None, None,
                    "unresolved product decision: %s" % (entry.question or entry.reason)))

    if not allow_undecided_policy:
        compensating = sorted({t for t in present
                               if (CARRY.get(t) is not None and CARRY[t].compensate)})
        if compensating and isinstance(COMPENSATION_POLICY, _Undecided):
            issues.append(Issue(
                "error", "<compensation>", None, None,
                "COMPENSATION_POLICY is UNDECIDED while these tables drop owned property: %s. "
                "See DECISIONS.md #2." % ", ".join(compensating)))
        if compensating and isinstance(COMPENSATION_ORDER, _Undecided):
            issues.append(Issue(
                "error", "<compensation>", None, None,
                "COMPENSATION_ORDER is UNDECIDED: before or after balance scaling gives different "
                "numbers. See DECISIONS.md #2."))
        if isinstance(BALANCE_SCALE_CONFIRMED, _Undecided):
            issues.append(Issue(
                "error", "<economy>", None, None,
                "BALANCE_SCALE is %s but nobody has confirmed it. 1:1 imports the old economy's inflation "
                "into an overhauled one — that is a decision, not an omission. Call set_balance_scale(...) "
                "even to keep 1:1. See DECISIONS.md #3." % BALANCE_SCALE))
        if BALANCE_SCALE != 1 and isinstance(BALANCE_ROUNDING, _Undecided):
            issues.append(Issue(
                "error", "<economy>", None, None,
                "BALANCE_SCALE is %s but the rounding direction is UNDECIDED; reconciliation checks totals "
                "against it. See DECISIONS.md #3." % BALANCE_SCALE))
        if isinstance(FREEZE, _Undecided):
            issues.append(Issue(
                "error", "<freeze>", None, None,
                "FREEZE is UNDECIDED: when the final dump is taken, whether there is a maintenance window, "
                "and when it was announced. See DECISIONS.md #4."))

    return issues


def validate(source_tables: Iterable[str], *,
             allow_unresolved_tables: bool = False,
             allow_undecided_policy: bool = False) -> list[Issue]:
    """Gate a run. Raises TransformError on the first error; returns the warnings.

    Both waivers are for the rehearsal loop only: they let the transform be
    exercised end to end against a scratch database before anybody has answered
    the questions. Neither downgrades an unlisted table — that is a defect in the
    policy, not an open question. See `check` for what each one waives.
    """
    issues = check(source_tables,
                   allow_unresolved_tables=allow_unresolved_tables,
                   allow_undecided_policy=allow_undecided_policy)
    errors = [i for i in issues if i.severity == "error"]
    if errors:
        summary = "; ".join("%s: %s" % (i.table, i.message) for i in errors[:5])
        if len(errors) > 5:
            summary += " (+%d more)" % (len(errors) - 5)
        first = errors[0]
        raise TransformError(Issue(first.severity, first.table, first.column, first.pk,
                                   "%d carry-over policy error(s): %s" % (len(errors), summary)))
    return [i for i in issues if i.severity == "warn"]


# ---------------------------------------------------------------------------
# Reporting helpers
# ---------------------------------------------------------------------------


def tables_by_mode(mode: str) -> list[str]:
    """Every table with the given mode, sorted. Raises on an unknown mode."""
    if mode not in MODES:
        raise ValueError("unknown carry mode %r" % mode)
    return sorted(t for t, c in CARRY.items() if c.mode == mode)


def open_questions() -> list[tuple[str, str]]:
    """(table, question) for every unresolved DECIDE, for the operator's report."""
    return [(t, CARRY[t].question or "") for t in tables_by_mode(DECIDE)]


def currency_columns() -> list[tuple[str, str]]:
    """(table, column) for every exact-integer money column that carries.

    Reconciliation sums these on both sides: total currency in must equal total
    currency out, scaled by BALANCE_SCALE and no more.
    """
    out: list[tuple[str, str]] = []
    for table, entry in sorted(CARRY.items()):
        if not entry.carries:
            continue
        for column in entry.currency:
            out.append((table, column))
    return out


def scaled_columns() -> list[tuple[str, str]]:
    """(table, column) for every currency column BALANCE_SCALE applies to."""
    return [(t, c) for t, entry in sorted(CARRY.items()) if entry.carries for c in entry.scaled]


def transcoded_columns() -> list[tuple[str, str]]:
    """EMPTY BY DECISION (owner, 2026-08-20, pg-native conversion).

    The codec columns stay TEXT holding the game's own mres blobs; nothing is
    transcoded to jsonb any more. jsonb bought no operator or index anywhere in
    the codebase, made every insert one backslash away from a hard failure, and
    forced a per-row-bimodal decode (game-written strings vs ETL-written
    documents) that took an engine-branched decoder to serve. The dev database
    was converted by tools/pgmigrate/migrate_codec_columns.py; a fresh target
    gets text columns from the DDL translator because this returns [].

    The per-table `transcode` sets in CARRY above are kept as the historical
    record of which columns USED to be transcoded -- do not resurrect them here.
    """
    return []


def boolean_columns() -> list[tuple[str, str]]:
    """(table, column) for every column that becomes a real `boolean`.

    An ALLOWLIST, and the reason it is one is `players.intake_path`: declared
    `tinyint(1)` and holding 0/1/2/3/9, so a blanket tinyint(1)->boolean rule
    would collapse five states into two — silently, for the values 0 and 1, which
    are most of them. The DDL translator is handed this list instead of a rule.
    """
    return [(t, c) for t, entry in sorted(CARRY.items()) if entry.carries for c in entry.booleans]


def added_columns() -> list[tuple[str, str, str]]:
    """(table, column, PostgreSQL definition) for target columns the source lacks."""
    return [(t, c, entry.add_columns[c])
            for t, entry in sorted(CARRY.items()) if entry.carries
            for c in sorted(entry.add_columns)]


def unpopulated_columns() -> list[tuple[str, str]]:
    """(table, column) that exist in the target but that this ETL does not write.

    The `drop` columns of every carried table. They are not holes in the schema —
    the target game writes them itself (`players.position` on logout,
    `lastupdated` on every save) — but a column nothing populates at load time is
    a fact the run should state rather than leave to be discovered.
    """
    return [(t, c) for t, entry in sorted(CARRY.items()) if entry.carries for c in entry.drop]


def reconciliation_plan() -> list[dict]:
    """The policy in the shape the reconciler needs: one dict per source table.

    WHY THIS IS HERE AND NOT THERE
        Reconciliation has to know which empty output tables are *expected*, and
        that is the same fact this file already states. Written down twice, the
        two copies drift, and the failure that drift produces is the worst one
        available: a table that stopped carrying, reconciling clean because the
        reconciler was told to expect zero rows.

        This is the REPORTING view — plain dicts, no import of `reconcile`, safe
        for a report or a diff. The auditor's actual rules are built by
        `reconcile_spec()` below, from the same CARRY table.

    Keys: table, disposition ("carry" | "drop" | "decide"), primary_key, reason,
    forced (columns overwritten on every row), currency, scaled.
    """
    plan: list[dict] = []
    for table, entry in sorted(CARRY.items()):
        if entry.carries:
            disposition = "carry"
        elif entry.mode == DROP:
            disposition = "drop"
        else:
            disposition = "decide"
        plan.append({
            "table": table,
            "disposition": disposition,
            "primary_key": tuple(entry.natural_key),
            "reason": entry.reason or "",
            "forced": dict(entry.force),
            "currency": tuple(entry.currency),
            "scaled": tuple(entry.scaled),
        })
    return plan


def reconcile_spec(*, allow_unresolved_tables: bool = False):
    """Build `reconcile.ReconcileSpec` from this policy. The auditor's rules, once.

    WHY THIS EXISTS
        `reconcile.py` is the only check in the package that re-derives the
        answer independently — its own dump parser, its own decoder, per-player
        id sets — and it could not be run at all: it requires `--spec`, and no
        spec file existed. Writing one by hand would have been worse than not
        having one, because a hand-written spec drifts from this file, and the
        drift's failure mode is the worst available: a table that stopped
        carrying, reconciling clean because the spec still said to expect zero
        rows. So the spec is generated from the policy, and the independence
        that matters — the parser, the decoder, the totals — is untouched.

    The vocabularies differ on purpose and are mapped here, in the open:
        carries        -> reconcile.DISP_CARRY   (every source row must appear)
        DROP           -> reconcile.DISP_DROP    (zero rows, and the reason why)
        DECIDE         -> REFUSED. There is no auditor rule for "nobody has
                          decided": an undecided table is not a filter, it is a
                          question. With `allow_unresolved_tables=True` (rehearsal only)
                          it becomes a DROP whose reason says so out loud.

    Every transcoded column carries an explicit empty policy. Without one the
    auditor treats an empty legacy value as an error, and `mres.decode_strict`
    returns `[]` for exactly that value — so a naive spec would have reported
    every empty inventory in the database as a finding and buried the real ones.

    KNOWN DIVERGENCE, recorded rather than papered over: at a scale other than
    1:1 with `half_up`, this file rounds an exact half toward +infinity while
    `reconcile.Scaling` rounds it away from zero. They agree on every
    non-negative balance and differ by one unit on a negative one that lands
    exactly on a half. Settle it before any run with a negative balance and a
    non-integer scale; at 1:1 nothing rounds at all.

    Usage:
        # carryover_spec.py
        from rules import reconcile_spec
        RECONCILE_SPEC = reconcile_spec()

    STATUS
        Unvalidated, like everything else here: no dump exists to run it against.
    """
    try:  # imported as `pgmigrate.rules`
        from . import reconcile as rc
    except ImportError:  # imported flat
        import reconcile as rc  # type: ignore

    rounding = "floor" if BALANCE_ROUNDING == ROUND_FLOOR_MODE else "half_up"
    scaling = rc.Scaling(numerator=BALANCE_SCALE.numerator,
                         denominator=BALANCE_SCALE.denominator,
                         rounding=rounding)

    tables: list[object] = []
    currency: list[object] = []
    encoded: list[object] = []
    dropped: dict[tuple[str, str], str] = {}
    renamed: dict[tuple[str, str], str] = {}

    for table, entry in sorted(CARRY.items()):
        if entry.mode == DECIDE:
            if not allow_unresolved_tables:
                raise TransformError(Issue(
                    "error", table, None, None,
                    "cannot build a reconciliation spec while this table's carry-over rule "
                    "is undecided: %s There is no auditor rule for an open question — "
                    "answer it in CARRY, or pass allow_unresolved_tables=True for a rehearsal, "
                    "which records it as a documented DROP."
                    % (entry.question or entry.reason or "")))
            tables.append(rc.TableRule(
                name=table, disposition=rc.DISP_DROP,
                primary_key=tuple(entry.natural_key),
                reason="UNRESOLVED (rehearsal waiver): rows are not migrated because nobody "
                       "has answered: %s" % (entry.question or entry.reason or "")))
            continue
        if entry.carries:
            tables.append(rc.TableRule(
                name=table, disposition=rc.DISP_CARRY,
                primary_key=tuple(entry.natural_key),
                reason=entry.reason or ""))
        else:
            tables.append(rc.TableRule(
                name=table, disposition=rc.DISP_DROP,
                primary_key=tuple(entry.natural_key),
                reason=entry.reason or ""))
            continue

        for column in entry.currency:
            places = DECIMAL_SCALES.get((table, column))
            currency.append(rc.CurrencyColumn(
                table=table, column=column,
                kind="decimal" if places else "integer",
                scale=places or 0,
                scaling=scaling if column in entry.scaled else rc.Scaling(),
                output_column=entry.rename.get(column)))
        for column in sorted(entry.transcode):
            encoded.append(rc.EncodingColumn(
                table=table, column=column,
                exhaustive=True,
                empty_policy=entry.empty_policy(column),
                output_column=entry.rename.get(column)))
        for column in entry.drop:
            dropped[(table, column)] = (
                "carry policy drops the VALUE of this column (the target keeps the column "
                "and fills it itself): see rules.CARRY[%r].drop" % table)
        for source_name, target_name in entry.rename.items():
            renamed[(table, source_name)] = target_name

    return rc.ReconcileSpec(
        tables=tuple(tables),
        identity=rc.IdentityRule(table=IDENTITY_TABLE, column=IDENTITY_COLUMN),
        currency=tuple(currency),
        encoded=tuple(encoded),
        # No foreign keys are declared: the source schema declares none either
        # (plan §2 — the constraints live in SQF, not in the database), so any
        # pair written here would be this file inventing a constraint the data
        # has never been held to. Add them deliberately, with evidence.
        foreign_keys=(),
        dropped_columns=dropped,
        renamed_columns=renamed,
        # The auditor re-derives compensation from the source rather than trusting
        # the ETL's own figure. Same policy, same owner resolution, computed
        # independently — so the two disagreeing is a finding, which is the only
        # reason to have an auditor at all.
        compensation=rc.CompensationRule(
            sources={source.table: name for name, source in sorted(COMPENSATION_SOURCES.items())},
            credit_table=COMPENSATION_CREDIT_TABLE,
            credit_column=COMPENSATION_CREDIT_COLUMN,
            credit_owner_column=COMPENSATION_CREDIT_OWNER_COLUMN,
            valuer=_reconcile_valuer,
            owner_of=_reconcile_owner,
            order=COMPENSATION_ORDER if isinstance(COMPENSATION_ORDER, str) else BEFORE_SCALING,
        ) if callable(COMPENSATION_POLICY) else None,
    )


def _reconcile_valuer(source_name: str, row: Mapping[str, object]) -> int:
    """COMPENSATION_POLICY, read at call time.

    Read late on purpose: a test that installs a different policy must be audited
    against the policy it installed, not against whichever one happened to be
    installed when the spec was built.
    """
    if not callable(COMPENSATION_POLICY):
        raise TransformError(Issue("error", "<compensation>", None, None,
                                   "the reconcile spec was built with a policy installed, but "
                                   "COMPENSATION_POLICY is no longer callable"))
    return COMPENSATION_POLICY(source_name, row)


def _reconcile_owner(source_name: str, row: Mapping[str, object]) -> str | None:
    """Owner resolution for the auditor, identical to the ETL's."""
    source = COMPENSATION_SOURCES[source_name]
    return _owner_uid(source, row, _pk_of(source.table, row))


def _selfcheck() -> None:
    """Fail at import if the policy table is internally inconsistent.

    A broken policy file must not be discoverable at row 400,000 of a beta-night
    load.
    """
    for table, entry in CARRY.items():
        if entry.compensate and entry.compensate not in COMPENSATION_SOURCES:
            raise ValueError("CARRY[%r] names unregistered compensation source %r" % (table, entry.compensate))
        if entry.compensate and entry.carries:
            raise ValueError("CARRY[%r] carries AND registers compensation; compensation is for dropped rows"
                             % table)
        if entry.rewrite and entry.rewrite not in ROW_REWRITES:
            raise ValueError("CARRY[%r] names row rewrite %r, which is not registered" % (table, entry.rewrite))
        if entry.mode in (DROP, DECIDE) and (entry.transcode or entry.defaults or entry.force):
            raise ValueError("CARRY[%r] is %s but describes column transforms" % (table, entry.mode))
    for name, source in COMPENSATION_SOURCES.items():
        if name != source.name:
            raise ValueError("COMPENSATION_SOURCES key %r does not match source name %r" % (name, source.name))
        if source.table not in CARRY:
            raise ValueError("compensation source %r names table %r, which has no CARRY entry"
                             % (name, source.table))
        if CARRY[source.table].compensate != name:
            raise ValueError("compensation source %r is not the one CARRY[%r] registers"
                             % (name, source.table))


# ---------------------------------------------------------------------------
# THE DECISIONS, AS ANSWERED
#
# Everything above is mechanism. This is the part a human chose, recorded in
# DECISIONS.md on 2026-08-15 and encoded here the same day, because an answer
# that lives only in a document is an answer the ETL cannot act on.
#
# Changing any of it after a run is not a config change. It is a data migration
# with players attached — see the DECISIONS.md change log.
# ---------------------------------------------------------------------------


def _tier_spend(tiers: Iterable[Iterable[int]], current_cap: object) -> int:
    """Money actually spent to reach `current_cap` on a storage upgrade ladder.

    Tier 0 is EXCLUDED. Its cap is seeded free with the house
    (`fn_handleHouse` case 1 writes the tier-0 caps on purchase) and its listed
    price is never charged — `fn_upgradeProperty` charges the price of the tier
    you are moving TO. The game's own house-value display in `fn_houseMenu`
    includes tier 0 and therefore over-states what the player spent; that is a
    resale figure, and this is a refund of purchase price.

    An unrecognised cap refunds the tiers at or below it rather than raising: a
    cap can legitimately sit off-ladder after a rebalance, and the honest answer
    is then "everything they demonstrably paid for", not a failed run.
    """
    cap = _as_int(current_cap)
    spend = 0
    for index, tier in enumerate(tiers):
        if index == 0:
            continue
        tier_cap, tier_price = tier[0], tier[1]
        if cap >= tier_cap:
            spend += int(tier_price)
    return spend


def purchase_price(source_name: str, row: Mapping[str, object]) -> int:
    """DECISIONS.md #2: refund what the player paid, in source currency units.

    Prices come from `prices.py`, which is GENERATED from the game's own config
    (`gen_prices.py`). Nothing here is a number chosen for the migration.

    WHAT THIS DELIBERATELY DOES NOT RECOVER, because the database does not
    record it per row and inventing it would be worse than stating it:

      * **Government tax on a house purchase.** `fn_buyHouse` charges
        `buyPrice + buyPrice * getGovTax`, the rate floats, and no column stores
        what was paid. The refund is the base price; the tax was revenue and is
        not refunded.
      * **The HOMESTEADER discounts.** Talent 211 buys a first house at -20% and
        212 takes -35% off storage upgrades. A player who had them paid less than
        this refunds. Erring high, for a player who has already lost the house.
      * **Whatever the seller charged on a player-to-player sale.** `houses.sale`
        is the current asking price, not what this owner paid for it.

    Raises rather than guessing when a classname has no price: a house or crate
    absent from the config is not a zero-value house, it is a parser or config
    problem, and a silent 0 is a refund nobody would ever notice was missing.
    """
    if source_name == "houses.compensation":
        classname = str(row.get("classname") or "")
        base = prices.HOUSE_BUY.get(classname)
        if base is None:
            raise TransformError(Issue(
                "error", "houses", "classname", row.get("oid"),
                "house classname %r has no price in prices.py. Either the config gained a building "
                "type and gen_prices.py has not been rerun, or the row is corrupt — both are worth "
                "stopping for, because the alternative is refunding this owner nothing."
                % classname))
        total = int(base)
        total += _tier_spend(prices.HOUSE_PHYS_TIERS.get(classname, []), row.get("phys_cap"))
        total += _tier_spend(prices.HOUSE_VIRT_TIERS.get(classname, []), row.get("vcap"))
        for column, key in (("barrel", "barrel"), ("greenhouse", "greenhouse"),
                            ("leadcontainer", "leadcontainer")):
            if _as_int(row.get(column)) == 1:
                total += int(prices.HOUSE_UPGRADES[key])
        keys_held = max(0, _as_int(row.get("keycap")))
        total += sum(int(c) for c in prices.KEY_SLOT_COSTS[:keys_held])
        return total

    if source_name == "storage.compensation":
        classname = str(row.get("classname") or "")
        price = prices.STORAGE_CRATE_BUY.get(classname)
        if price is None:
            raise TransformError(Issue(
                "error", "storage", "classname", row.get("id"),
                "storage crate %r has no price in prices.py; fn_placeStorage spawns exactly three "
                "crate classes and this is not one of them" % classname))
        return int(price)

    if source_name == "house_rigs.compensation":
        # A rig is assembled from eight scavenged components, never bought, so
        # its purchase price is what those components cost: RIG_BUY, which is
        # tiny. That is the money-faithful answer and it under-values the effort
        # by a lot. Left as the honest number rather than quietly inflated — if
        # the owner wants rigs paid out at a headline figure, that is a decision,
        # and it belongs in DECISIONS.md with a date on it.
        return int(prices.RIG_BUY)

    if source_name == "atm_skimmers.compensation":
        return int(prices.SKIMMER_BUY)

    if source_name == "suites.compensation":
        # A lease, not a freehold, and the game's own rule for ending one is
        # explicit: "No refund of the current month" (suites.md §, End Lease and
        # Repossession). Rent already paid was consumed month by month, and there
        # is no purchase price to refund. Zero is the answer the live game would
        # give the same player on the same day.
        #
        # Also, at the time of writing, suites are spec-approved and unbuilt, so
        # this source is expected to see zero rows. It is implemented anyway: a
        # source that raises on its first row during a beta-night run is worse
        # than one that returns a documented 0.
        return 0

    raise TransformError(Issue(
        "error", "<compensation>", None, None,
        "no purchase price is defined for compensation source %r. A new source must be priced "
        "here deliberately; falling through to 0 would pay nothing and report success."
        % source_name))


set_compensation_policy(purchase_price)

# Before, not after. At 1:1 the two orders give the same number, so this is inert
# today — recorded anyway, because the moment the factor is not 1:1 it stops being
# inert and nobody will remember that it was never actually chosen.
set_compensation_order(BEFORE_SCALING)

# 1:1, and 1:1 IS the decision, not the absence of one. BALANCE_ROUNDING is left
# UNDECIDED on purpose: nothing rounds at 1:1, and leaving it unset means anyone
# who later changes the factor hits the gate instead of inheriting a rounding
# direction this line would have chosen for them.
set_balance_scale(Fraction(1, 1))
BALANCE_SCALE_CONFIRMED = True

# DECISIONS.md #4, answered 2026-08-15: the switchover is 2026-09-11, behind a
# maintenance window, announced the day before.
#
# The instant is 14:00 UTC = 09:00 CDT, which is the moment the box's own deploy
# freeze (22:00-09:00 local) lifts — the earliest hour a deploy is allowed to
# happen at all. Adjust the hour freely; what must not drift is that the dump
# instant and the announcement say the same thing to players.
#
# A maintenance window means nobody loses progress: live goes read-only or down,
# the final dump is taken from a server nobody is playing, and the new one opens
# after. The alternative was a known delta, and it was declined.
set_freeze(Freeze(
    dump_taken_utc="2026-09-11T14:00:00Z",
    maintenance_window=True,
    announced_on="2026-09-10",
))

_selfcheck()
