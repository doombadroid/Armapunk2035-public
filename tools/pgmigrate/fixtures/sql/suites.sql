-- suites — leased floors of the Skyscraper30 lux tower (spec: suites.md)
--
-- A suite is one whole floor (2..30) of one lux tower instance. Deliberately NOT
-- the houses table: the tower is a createSimpleObject p3d that no house code path
-- can resolve, and houses.oid is a rounded X/Y position hash that every floor of a
-- tower would collide on.
--
-- oid   = LUX<roundX><roundY>F<floor>, e.g. LUX72177777F7. The tower's rounded
--         world position keys the instance, the floor disambiguates within it, so
--         multiple lux towers each get their own set of 29 rows.
-- tower = the <roundX><roundY> part on its own, so a whole tower can be swept.
--
-- All timestamps are RAW UNIX (UNIX_TIMESTAMP()), never DATETIME: deltas are
-- timezone-independent, which sidesteps the box-CST / DB-UTC split documented in
-- server/AP_server/init.sqf. SQF must write them with `toFixed 0` — formatting a
-- large number with %1 renders scientific notation and corrupted houses.miner once.
--
-- Rows are created on first lease and kept forever. Ending a lease (voluntarily or
-- by repossession) NULLs owner + the payload columns but leaves the row.

CREATE TABLE IF NOT EXISTS `suites` (
  `id`             INT(11)          NOT NULL AUTO_INCREMENT,
  `oid`            VARCHAR(32)      NOT NULL,                -- LUX<x><y>F<nn>
  `tower`          VARCHAR(24)      NOT NULL,                -- <x><y>
  `floor`          TINYINT(4)       NOT NULL,                -- 2..30
  `owner`          VARCHAR(17)      DEFAULT NULL,            -- Steam64; NULL = vacant
  `leased_at`      INT(10) UNSIGNED NOT NULL DEFAULT 0,      -- unix
  `next_due`       INT(10) UNSIGNED NOT NULL DEFAULT 0,      -- unix, rent deadline
  `overdue_since`  INT(10) UNSIGNED NOT NULL DEFAULT 0,      -- unix; 0 = paid up
  `locked`         TINYINT(1)       NOT NULL DEFAULT 1,
  `vinv`           TEXT             DEFAULT NULL,            -- mres, as houses.vinv
  `pinv`           TEXT             DEFAULT NULL,            -- mres, as houses.pinv
  `furniture`      TEXT             DEFAULT NULL,            -- mres [class,posATL,dir,uid]
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_oid` (`oid`),
  KEY `idx_owner` (`owner`),
  KEY `idx_due` (`owner`, `next_due`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
