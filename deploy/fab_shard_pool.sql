-- FABRICATOR SHARD CONSERVATION (fn_fabGrantSRV "burn" / "shard", mints audit 2026-09-26).
--
-- One row per shard tier (0 = shard, 1 = shard_rare, 2 = shard_epic): how many burned shards of that tier are
-- still waiting to be decrypted. "burn" adds one, a successful "shard" decrypt takes one, and a decrypt with
-- nothing left to take is refused -- so decrypts can never outnumber burns, whatever shards a client claims.
-- The server creates the table itself on first use; this file exists for the SEED.
--
-- RUN ONCE, DURING THE DEPLOY, BEFORE THE FIRST BOOT OF THE BUILD THAT CARRIES THIS. The seed credits every
-- shard burned before now that has not been decrypted, from the `log` table's -FAB- rows, so shards players
-- already hold keep decrypting. Those rows are trustworthy only because forging one bought nothing until this
-- build: any client can write a -FAB- row through APS_fnc_logIt, so a seed run AFTER the build is live would
-- let a forger mint decrypts. ON CONFLICT DO NOTHING: a tier the server has already counted is left alone, and a
-- second run changes nothing.

CREATE TABLE IF NOT EXISTS fab_shard_pool (
    tier smallint NOT NULL,
    burned integer NOT NULL DEFAULT 0,
    CONSTRAINT fab_shard_pool_pkey PRIMARY KEY (tier)
);

INSERT INTO fab_shard_pool (tier, burned)
SELECT t.tier, GREATEST(0,
         (SELECT count(*) FROM log WHERE tag = '-FAB-' AND message ~ ('^burned schematic .* -> ' || t.item || '( |$)'))
       - (SELECT count(*) FROM log WHERE tag = '-FAB-' AND message ~ ('^learned schematic .* via shard:' || t.item || '( |$)')))
FROM (VALUES (0, 'shard'), (1, 'shard_rare'), (2, 'shard_epic')) AS t(tier, item)
ON CONFLICT (tier) DO NOTHING;

SELECT tier, burned FROM fab_shard_pool ORDER BY tier;
