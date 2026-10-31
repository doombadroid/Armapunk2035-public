-- pgmigrate integration fixture. NOT a dump of anything real.
--
-- WHY THIS FILE EXISTS: the unit tests give `etl` stand-ins for `ddl`, `rules`
-- and `mres`, so each module is proved against its own idea of the others and
-- the seams between them are never exercised. Four bugs lived in exactly those
-- seams, all of them invisible to a green unit-test run and all of them fatal at
-- `psql` time. This dump is small enough to read and shaped like the real thing:
-- the columns `rules.CARRY` names, in the types the live schema declares.
--
-- Hand-checked properties this fixture carries deliberately:
--   * `players.intake_path` holds 9  — a tinyint(1) that is NOT a flag, which a
--     blanket tinyint(1)->boolean rule destroys silently for the values 0 and 1;
--   * `cash` above 2**53 and a 14-digit `new_drachma` with a non-zero fourth
--     decimal — the two values a float would quietly round;
--   * an apostrophe in a name, escaped the backslash way;
--   * a `houses` row, so the compensation path has property to value.

CREATE TABLE `players` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `playerid` varchar(17) NOT NULL,
  `name` varchar(64) NOT NULL DEFAULT 'Error',
  `cash` bigint(20) NOT NULL DEFAULT 0,
  `bankacc` bigint(20) NOT NULL DEFAULT 0,
  `new_drachma` decimal(20,4) NOT NULL DEFAULT 0.0000,
  `aliases` text DEFAULT NULL,
  `arrested` text DEFAULT NULL,
  `civ_gear` text DEFAULT NULL,
  `civ_licenses` text DEFAULT NULL,
  `civ_talents` text DEFAULT NULL,
  `completed_quests` text DEFAULT NULL,
  `cop_gear` text DEFAULT NULL,
  `cop_licenses` text DEFAULT NULL,
  `cop_talents` text DEFAULT NULL,
  `crimes` text DEFAULT NULL,
  `gov_data` text DEFAULT NULL,
  `infamy_talents` text DEFAULT NULL,
  `med_gear` text DEFAULT NULL,
  `med_licenses` text DEFAULT NULL,
  `med_talents` text DEFAULT NULL,
  `medic_talents` text DEFAULT NULL,
  `pre_talents` text DEFAULT NULL,
  `prestige` text DEFAULT NULL,
  `progress_quests` text DEFAULT NULL,
  `isswat` tinyint(1) NOT NULL DEFAULT 0,
  `isfirefighter` tinyint(1) NOT NULL DEFAULT 0,
  `new_player` tinyint(1) NOT NULL DEFAULT 0,
  `isdetective` tinyint(1) NOT NULL DEFAULT 0,
  `casino_banned` tinyint(1) NOT NULL DEFAULT 0,
  `intake_path` tinyint(1) NOT NULL DEFAULT 0,
  `intake_step` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `instance` int(11) NOT NULL DEFAULT 1,
  `position` text DEFAULT NULL,
  `alive` tinyint(1) NOT NULL DEFAULT 0,
  `damage` double NOT NULL DEFAULT 0,
  `lastupdated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `playerid` (`playerid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO `players` VALUES
 (1,'76500000000000001','O\'Brien',9007199254740993,250000,12345678901234.5678,'`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`cop`,1],[`med`,0]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`cop`,1],[`med`,0]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`cop`,1],[`med`,0]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`',1,0,0,0,0,9,7,1,'[3200.5,12800.25,0]',1,0.35,'2026-08-10 21:14:03'),
 (2,'76500000000000002','Ada',25,0,0.0001,'`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`cop`,1],[`med`,0]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`cop`,1],[`med`,0]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`cop`,1],[`med`,0]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`',0,0,0,0,0,0,7,1,'[3200.5,12800.25,0]',1,0.35,'2026-08-10 21:14:03'),
 (3,'76500000000000003','Ghost',0,17,0.0000,'`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`cop`,1],[`med`,0]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`cop`,1],[`med`,0]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`cop`,1],[`med`,0]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`','`[[`item_a`,3],[`item_b`,1]]`',0,0,0,0,0,1,7,1,'[3200.5,12800.25,0]',1,0.35,'2026-08-10 21:14:03');

CREATE TABLE `player_names` (
  `playerid` varchar(17) NOT NULL,
  `name` varchar(64) NOT NULL,
  PRIMARY KEY (`playerid`,`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO `player_names` VALUES ('76500000000000001','O\'Brien'),('76500000000000002','Ada');

CREATE TABLE `vehicles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `side` varchar(16) NOT NULL,
  `classname` varchar(64) NOT NULL,
  `type` varchar(16) NOT NULL,
  `pid` varchar(17) NOT NULL,
  `alive` tinyint(1) NOT NULL DEFAULT 1,
  `active` tinyint(1) NOT NULL DEFAULT 0,
  `listed` tinyint(1) NOT NULL DEFAULT 0,
  `alarm` tinyint(1) NOT NULL DEFAULT 0,
  `plate` int(11) NOT NULL,
  `inventory` text DEFAULT NULL,
  `mods` text DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO `vehicles` VALUES
 (1,'civ','B_Quadbike_01_F','Car','76500000000000001',1,1,1,0,140021,'`[[`item_a`,3]]`','`[]`'),
 (2,'civ','C_Offroad_01_F','Car','76500000000000002',0,0,0,1,140022,'`[]`','`[]`');

CREATE TABLE `houses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `oid` varchar(32) NOT NULL,
  `owners` varchar(17) NOT NULL,
  `classname` varchar(64) NOT NULL,
  `sale` int(11) NOT NULL DEFAULT 0,
  `worldspace` text NOT NULL,
  `vinv` text DEFAULT NULL,
  `pinv` text DEFAULT NULL,
  `keyholders` text DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO `houses` VALUES
 (1,'H14200_16100','76500000000000001','Land_i_House_Big_01_V1_F',500000,'[[14200,16100,0],180]','`[]`','`[]`','`[]`'),
 (2,'H14300_16200','76500000000000002','Land_i_House_Small_02_V1_F',120000,'[[14300,16200,0],90]','`[]`','`[]`','`[]`');

