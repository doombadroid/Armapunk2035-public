-- LooneyBin 2026-07-16: ATM SKIMMER persistence. One row per skimmed physical ATM, keyed by its rounded
-- world position ("x_y") so it survives restarts (mapData/world ATM objects are at fixed positions). owner_uid
-- = the rebel who planted it (gets 10% of every transaction at that ATM). Cops remove for a bounty.
CREATE TABLE IF NOT EXISTS atm_skimmers (
    atm_key   VARCHAR(32) NOT NULL PRIMARY KEY,   -- format("%1_%2", round posX, round posY)
    owner_uid VARCHAR(32) NOT NULL,
    applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
