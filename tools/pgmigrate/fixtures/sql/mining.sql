-- Mining rigs.
-- LEGACY (single-rig, live b0182): houses.miner = "sinceUnix:lastCollectUnix" varchar(48). RETIRED by
-- multi-rig; kept here because live still has it until the multi-rig ship. Idempotent.
ALTER TABLE houses ADD COLUMN IF NOT EXISTS miner VARCHAR(48) DEFAULT NULL;

-- MULTI-RIG (2026-07-22): one row per placed rig (max 5/player), replaces houses.rig/miner.
-- since/last_collect are INT columns written via `toFixed 0` -- never format a numeric stamp with %N
-- (SQF renders large numbers scientific, e.g. 8.4554e+07; that plus a row-vs-cell read bug is what
-- corrupted live houses.miner and enabled the infinite collect dupe).
CREATE TABLE IF NOT EXISTS house_rigs (
  id INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  oid VARCHAR(64) NOT NULL,
  owner VARCHAR(32) NOT NULL,
  pos VARCHAR(96) NOT NULL,
  since INT(10) UNSIGNED NOT NULL,
  last_collect INT(10) UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  KEY idx_oid (oid),
  KEY idx_owner (owner)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------------------------------------
-- LIVE MIGRATION (run ONCE at the multi-rig ship, after a backup -- do NOT run before then):
-- Live houses.miner is CORRUPTED by the b0182 collect bug: each collect wrote the whole result-row
-- array back (`["[""...` prefixes, quotes doubling per collect) until the string hit varchar(48) under
-- STRICT_TRANS_TABLES; from then on the UPDATE was silently rejected, last_collect froze, and every
-- collect re-minted the capped 96 LoonyCoin (10 of 13 live rigs frozen as of 2026-07-22).
--   * Do NOT parse houses.miner -- treat every stamp in it as untrusted.
--   * Convert PLACEMENTS only (houses.rig = "x:y:z:dir" is clean; written once, never rewritten).
--   * Start accrual at migration time (since = last_collect = UNIX_TIMESTAMP()). Frozen rigs already
--     over-minted; granting their "pending" accrual would pay the dupe out one final time.
--   * Rig owner = the HOUSE owner's Steam64. houses.owners is a nested-array string -- resolve it in
--     the migration script (deploy tooling), not in raw SQL; verify each extracted UID is 17 digits.
--   * After the INSERTs: UPDATE houses SET rig=NULL, miner=NULL WHERE rig IS NOT NULL; -- retire slots
-- ---------------------------------------------------------------------------------------------------
