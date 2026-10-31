-- ============================================================================
--  looneybin_schema.sql  —  REAL schema, reverse-engineered from the 2017
--  Loonybin server SQL (server/AP_server/core/DB/*.sqf). Unlike the inferred
--  2020 guess (sql/_inferred_2020_schema.sql), every column here is proven by
--  an actual INSERT/SELECT/UPDATE in the 2017 source.
--
--  CONSOLIDATED for the revival: the 2017 code split data across `arma3life`
--  (players, players_global) and `loonybinlife<N>` (houses, gangs, storage) and
--  used a mix of extDB2 + Arma2NET. Here everything is ONE database for a clean
--  extDB3 setup. Multi-server stays supported via the `instance` column and the
--  per-instance gang columns (gang0/gangrank0 ... add more per instance).
--
--  See docs/DB_LAYER_2017.md for the architecture + migration notes.
--  Engine: MySQL 5.7+/MariaDB 10.x.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS `looneybin`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `looneybin`;

-- ----------------------------------------------------------------------------
-- players  (was arma3life.players / srv_table_players)
--   per-character, per-instance. Arrays stored backtick-encoded TEXT.
--   gang<N>/gangrank<N> are per-instance columns (add one pair per server id).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `players` (
  `id`             INT(11)      NOT NULL AUTO_INCREMENT,
  `playerid`       VARCHAR(17)  NOT NULL,                 -- Steam UID  (load idx 0)
  `name`           VARCHAR(64)  NOT NULL DEFAULT 'Error',
  `aliases`        TEXT,
  `instance`       INT(11)      NOT NULL DEFAULT 0,
  -- wallet (shared across sides)
  `cash`           BIGINT(20)   NOT NULL DEFAULT 0,        -- load 1  / save mode 0,6
  `bankacc`        BIGINT(20)   NOT NULL DEFAULT 50000,    -- load 2  / save mode 1,6  (new-player starting bank)
  `new_drachma`    DECIMAL(20,4) NOT NULL DEFAULT 0,       -- ND wallet (server-authoritative) / load 23
  -- gear + licenses per side (backtick arrays). load 6 = current side's gear / mode 3,17
  `civ_gear`       TEXT,
  `cop_gear`       TEXT,
  `med_gear`       TEXT,
  `civ_licenses`   TEXT,                                  -- mode 2
  `cop_licenses`   TEXT,
  `med_licenses`   TEXT,
  -- progression per side. load 8/9 = current side exp/talents / mode 4
  `civ_talents`    TEXT,
  `cop_talents`    TEXT,                                  -- mode 16 (with prestige)
  `med_talents`    TEXT,
  `civ_exp`        BIGINT(20)   NOT NULL DEFAULT 100,
  `cop_exp`        BIGINT(20)   NOT NULL DEFAULT 0,
  `med_exp`        BIGINT(20)   NOT NULL DEFAULT 0,
  `medic_prestige` BIGINT(20)   NOT NULL DEFAULT 0,        -- LooneyBin medic/TT prestige points  (queryRequest %3 -> AP_medic_exp)
  `medic_talents`  TEXT,                                  -- LooneyBin medic/TT prestige talents (queryRequest %4 -> AP_medic_talents)
  `prestige`       TEXT,                                  -- cop load 16 / mode 16
  `infamy_exp`     BIGINT(20)   NOT NULL DEFAULT 0,        -- civ load 19 / mode 22
  `infamy_talents` TEXT,                                  -- civ load 20 / mode 22
  -- civ state
  `arrested`       TEXT,                                  -- AP_is_arrested / load 15 / mode 5
  `crimes`         TEXT,                                  -- A_stats_crimes / load 16 / mode 8
  `position`       TEXT,                                  -- last_pos / load 17 / mode 10
  `gov_data`       TEXT,                                  -- load 30 / mode 21
  `completed_quests` TEXT,                                -- load 26[0] / mode 20
  `progress_quests`  TEXT,                                -- load 26[1] / mode 20
  -- cosmetics + side flags
  `title`          INT(11)      NOT NULL DEFAULT -1,       -- title id / load 25 / mode 19 (-1 none)
  `prefix`         VARCHAR(32)  NOT NULL DEFAULT '',       -- load 10 / mode 15
  `ismaxtac`       TINYINT(1)   NOT NULL DEFAULT 0,        -- cop load 20
  `isscd`          TINYINT(1)   NOT NULL DEFAULT 0,        -- cop load 23 (undercover/SCD whitelist; gates cop_scd_* slots -- pure whitelist, replaced the Sgt+ rank gate)
  `isfirefighter`  TINYINT(1)   NOT NULL DEFAULT 0,        -- med load 21
  `casino_banned`  TINYINT(1)   NOT NULL DEFAULT 0,        -- load slot 37 (casino self-exclusion; Settings "Casino Ban" -> AP_casinoBanned + server AP_bjBanned; admin-only undo)
  `wheel_last_free` DATETIME              DEFAULT NULL,     -- Casino Wheel Spin: last FREE daily spin (NULL = never); free again when < NOW()-24h (APS_fnc_casinoSRV "wheel")
  -- gang (per instance; add gang1/gangrank1 ... per server id)
  `gang0`          INT(11)               DEFAULT NULL,     -- load 28
  `gangrank0`      INT(11)      NOT NULL DEFAULT 5,
  -- 2017-compat (used by surviving 2017 server fns: setDeadState, restoreVehicles)
  `alive`          TINYINT(1)   NOT NULL DEFAULT 1,
  `damage`         DOUBLE       NOT NULL DEFAULT 0,
  `thirst`         DOUBLE       NOT NULL DEFAULT 100,
  `hunger`         DOUBLE       NOT NULL DEFAULT 100,
  `new_player`     TINYINT(1)   NOT NULL DEFAULT 1,        -- load 31
  `lastupdated`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `playerid` (`playerid`),
  KEY `gang0` (`gang0`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- players_global  (cross-instance per player)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `players_global` (
  `playerid`            VARCHAR(17) NOT NULL,
  `adminlevel`          TINYINT(2)  NOT NULL DEFAULT 0,    -- load 3
  `eventcoordinatorlvl` TINYINT(2)  NOT NULL DEFAULT 0,    -- load 4
  `donorlevel`          TINYINT(2)  NOT NULL DEFAULT 0,    -- load 5
  `coplevel`            TINYINT(2)  NOT NULL DEFAULT 0,    -- cop load 15
  `copretired`          TINYINT(2)  NOT NULL DEFAULT 0,    -- cop load 24
  `mediclevel`          TINYINT(2)  NOT NULL DEFAULT 0,    -- med load 15
  `subscribed`          TINYINT(1)  NOT NULL DEFAULT 0,    -- load civ24/cop19/med17
  `achievements`        TEXT,                              -- load 11 / mode 7
  `stats`               TEXT,                              -- A_stats[17] / load 14 / mode 9
  `honor_exp`           BIGINT(20)  NOT NULL DEFAULT 0,    -- load 21 / mode 14
  `honor_talents`       TEXT,                              -- load 22 / mode 14
  `lootrewards`         TEXT,                              -- load 12
  `lootkeys`            TEXT,                              -- load 13
  `keys`                TEXT,                              -- house/veh key holdings
  `wealth`              BIGINT(20)  NOT NULL DEFAULT 0,
  `mailbox`             TEXT,
  `betatester`          TINYINT(1)  NOT NULL DEFAULT 0,    -- load 35 -> AP_betaTester (beta-tester whitelist; gates beta shirt)
  PRIMARY KEY (`playerid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- vehicles  (srv_table_vehicles)   fuel/damage/ammo stored *100 as INT
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `vehicles` (
  `id`         INT(11)     NOT NULL AUTO_INCREMENT,
  `side`       VARCHAR(8)  NOT NULL,                      -- cop / civ / med
  `classname`  VARCHAR(64) NOT NULL,
  `type`       VARCHAR(16) NOT NULL,                      -- Car/Air/Ship/...
  `pid`        VARCHAR(17) NOT NULL,                      -- owner UID
  `alive`      TINYINT(1)  NOT NULL DEFAULT 1,
  `active`     TINYINT(1)  NOT NULL DEFAULT 1,            -- 0 = garaged
  `listed`     TINYINT(1)  NOT NULL DEFAULT 0,            -- on market
  `inventory`  TEXT,
  `color`      INT(11)     NOT NULL DEFAULT 0,
  `plate`      INT(11)     NOT NULL DEFAULT 0,
  `fuel`       INT(11)     NOT NULL DEFAULT 100,
  `damage`     INT(11)     NOT NULL DEFAULT 0,
  `alarm`      TINYINT(1)  NOT NULL DEFAULT 0,
  `ammo`       INT(11)     NOT NULL DEFAULT 0,
  `mods`       TEXT,                                      -- 9-slot upgrade array "[alarm,trunk,handling,horn,nitro,tracker,pstor,locks,doors]" (APS_fnc_updateVehicleMods / fn_getVehicles)
  PRIMARY KEY (`id`),
  KEY `pid` (`pid`),
  KEY `lookup` (`pid`,`alive`,`active`,`side`,`type`,`listed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- houses  (was loonybinlife<N>.houses)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `houses` (
  `id`         INT(11)     NOT NULL AUTO_INCREMENT,
  `oid`        VARCHAR(32) NOT NULL,                      -- in-world object id
  `owners`     VARCHAR(17) NOT NULL,                      -- owner UID
  `locked`     TINYINT(1)  NOT NULL DEFAULT 1,
  `worldspace` TEXT        NOT NULL,                      -- pos array
  `sale`       BIGINT(20)  NOT NULL DEFAULT 0,            -- >0 = for sale at price
  `instance`   INT(11)     NOT NULL DEFAULT 0,
  `vcap`          INT(11)     NOT NULL DEFAULT 0,          -- virtual storage capacity
  `phys_cap`      INT(11)     NOT NULL DEFAULT 0,          -- physical storage capacity
  `keycap`        INT(11)     NOT NULL DEFAULT 0,          -- spare-key slots created
  `barrel`        TINYINT(1)  NOT NULL DEFAULT 0,          -- aging barrel upgrade
  `greenhouse`    TINYINT(1)  NOT NULL DEFAULT 0,          -- greenhouse upgrade
  `leadcontainer` TINYINT(1)  NOT NULL DEFAULT 0,          -- lead container upgrade
  `keyholders`    TEXT,                                    -- [[uid,rank,name],...] mres-encoded
  `vinv`          TEXT,                                    -- virtual storage [[items],weight] mres-encoded
  `pinv`          TEXT,                                    -- physical storage [[items],weight] mres-encoded
  `greenhouse_crop` TEXT,                                  -- house weed crop [[strain,plantedUnix,count],...] (was ALTER-added)
  `barrel_crop`   TEXT,                                    -- owner 2026-06-21: house spirit aging [[type,laidUnix,count],...] (APS_fnc_barrelSRV)
  PRIMARY KEY (`id`),
  KEY `owners` (`owners`),
  KEY `worldspace` (`worldspace`(64))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- gangs  (was loonybinlife<N>.gangs)   id = gang-house build id
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `gangs` (
  `id`          INT(11)     NOT NULL,
  `name`        VARCHAR(32) NOT NULL,
  `wars`        TEXT,
  `inviterank`  INT(11)     NOT NULL DEFAULT 2,
  `kickrank`    INT(11)     NOT NULL DEFAULT 2,
  `bank`        BIGINT(20)  NOT NULL DEFAULT 0,
  `experience`  BIGINT(20)  NOT NULL DEFAULT 0,
  `talents`     TEXT,
  `instance`    INT(11)     NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- wars   gang-vs-gang war pairs   (one row per active war)
-- This is the LIVE war store: fn_updateWar INSERTs (accept) / DELETEs (surrender);
-- fn_query.sqf loads AP_gang_wars from it on each gang member's login. It was
-- MISSING from the DB -> every "Accept War" INSERT errored 1146 -> wars never
-- persisted ("can't accept gang wars", owner 2026-06-23). The `gangs`.`wars` TEXT
-- column above is vestigial (read into the cache but never written/used for state).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `wars` (
  `id`    INT(11) NOT NULL AUTO_INCREMENT,
  `gang1` INT(11) NOT NULL,                                -- gangs.id
  `gang2` INT(11) NOT NULL,                                -- gangs.id
  PRIMARY KEY (`id`),
  KEY `idx_gang1` (`gang1`),
  KEY `idx_gang2` (`gang2`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- storage  (was loonybinlife<N>.storage)   house crates/containers
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `storage` (
  `id`              INT(11)     NOT NULL AUTO_INCREMENT,
  `houseid`         INT(11)     NOT NULL,
  `worldspace`      TEXT,                                 -- container pos
  `container`       INT(11)     NOT NULL DEFAULT -1,      -- pos index in house
  `classname`       VARCHAR(64) NOT NULL,
  `contents`        TEXT,                                 -- physical items
  `virtual`         TEXT,                                 -- [virtualItems, money]
  `houseworldspace` TEXT,                                 -- parent house pos
  PRIMARY KEY (`id`),
  KEY `houseid` (`houseid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- wanted  (srv_table_wanted)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `wanted` (
  `playerid`  VARCHAR(17) NOT NULL,
  `name`      VARCHAR(64) NOT NULL,
  `crimes`    TEXT,                                       -- backtick array of charges
  `bounty`    BIGINT(20)  NOT NULL DEFAULT 0,
  `jail`      INT(11)     NOT NULL DEFAULT 0,             -- jail time owed
  PRIMARY KEY (`playerid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- config   (ordered server config -> AP_configuration)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `config` (
  `index`  INT(11)     NOT NULL,
  `value`  TEXT,
  PRIMARY KEY (`index`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- online   (presence; cleared per instance on boot)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `online` (
  `playerid`  VARCHAR(17) NOT NULL,
  `name`      VARCHAR(64),
  `instance`  INT(11)     NOT NULL DEFAULT 0,
  PRIMARY KEY (`playerid`,`instance`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- captures   (cartel capture points)   id 1-based; percent stored *100
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `captures` (
  `id`         INT(11)    NOT NULL,
  `gang`       INT(11)              DEFAULT NULL,         -- owning gang id
  `percent`    INT(11)    NOT NULL DEFAULT 0,
  `container`  TEXT,                                      -- stash contents
  `level`      INT(11)    NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- turf   (gang turf control)   id 1-based
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `turf` (
  `id`    INT(11)  NOT NULL,
  `gang`  INT(11)           DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- itemstock   (was loonybinlife<N>.itemstock)   dynamic market pricing stock
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `itemstock` (
  `className`  VARCHAR(64) NOT NULL,
  `quantity`   BIGINT(20)  NOT NULL DEFAULT 0,
  PRIMARY KEY (`className`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- All 12 tables now pinned from real 2017 SQL:
--   players, players_global, vehicles, houses, gangs, storage, wanted,
--   config, online, captures, turf, itemstock
-- ============================================================================

-- ----------------------------------------------------------------------------
-- gang_vehicles  (2020 gang garage)  COLUMN ORDER MATTERS: SELECT * indices must
-- line up with fn_gangGarageMenu (0=id,2=classname,4=gang_id,7=plate,8=color,...).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `gang_vehicles` (
  `id`         INT(11)     NOT NULL AUTO_INCREMENT,    -- idx 0 (lbValue)
  `pid`        VARCHAR(17) NOT NULL,                   -- idx 1 (adder uid)
  `classname`  VARCHAR(64) NOT NULL,                   -- idx 2
  `type`       VARCHAR(16) NOT NULL DEFAULT 'Car',     -- idx 3
  `gang_id`    INT(11)     NOT NULL,                   -- idx 4
  `inventory`  TEXT,                                   -- idx 5
  `active`     TINYINT(1)  NOT NULL DEFAULT 0,         -- idx 6 (0 = in garage)
  `plate`      INT(11)     NOT NULL DEFAULT 0,         -- idx 7
  `color`      INT(11)     NOT NULL DEFAULT 0,         -- idx 8
  `fuel`       INT(11)     NOT NULL DEFAULT 100,       -- idx 9
  `damage`     INT(11)     NOT NULL DEFAULT 0,         -- idx 10
  `alarm`      TINYINT(1)  NOT NULL DEFAULT 0,         -- idx 11
  `mods`       TEXT,                                   -- idx 12
  `insert_time` DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `gang_id` (`gang_id`,`active`,`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- loadouts  (2020 saved loadouts; fetchLoadouts/handleLoadouts)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `loadouts` (
  `id`         INT(11)     NOT NULL AUTO_INCREMENT,
  `pid`        VARCHAR(17) NOT NULL,
  `side`       VARCHAR(8)  NOT NULL,                   -- civ/cop/med
  `slot`       INT(11)     NOT NULL DEFAULT 0,
  `name`       VARCHAR(64),
  `gear`       TEXT,
  `currency`   VARCHAR(16) NOT NULL DEFAULT 'cash',
  PRIMARY KEY (`id`),
  KEY `pid_side` (`pid`,`side`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- bounties  (2020 persistent player bounties; srvPersistentBounties)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `bounties` (
  `id`          INT(11)     NOT NULL AUTO_INCREMENT,
  `target_uid`  VARCHAR(17) NOT NULL,
  `target_name` VARCHAR(64) NOT NULL,
  `amount`      BIGINT(20)  NOT NULL DEFAULT 0,
  `placed_by`   VARCHAR(17),
  `insert_time` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `target_uid` (`target_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- Stored procedures called on server boot (server/AP_server/init.sqf).
-- Original bodies were in the DB (not in the leak) -> RECONSTRUCTED, sensible
-- defaults: on restart, return all spawned vehicles to the garage (active=0).
-- ----------------------------------------------------------------------------
DELIMITER //

DROP PROCEDURE IF EXISTS resetLifeVehicles //
CREATE PROCEDURE resetLifeVehicles()
BEGIN
    UPDATE `vehicles` SET `active` = 0 WHERE `active` = 1;
END //

DROP PROCEDURE IF EXISTS resetAusVehicles //
CREATE PROCEDURE resetAusVehicles()
BEGIN
    UPDATE `vehicles` SET `active` = 0 WHERE `active` = 1;
END //

-- House upkeep on boot. Original tax/decay logic unknown -> no-op stub.
-- TODO: reconstruct house tax/maintenance if/when the gameplay rule is pinned.
DROP PROCEDURE IF EXISTS updateLifeHouses //
CREATE PROCEDURE updateLifeHouses()
BEGIN
    SELECT 1;
END //

DELIMITER ;

-- ----------------------------------------------------------------------------
-- server_control + restart_log (owner 2026-06-13): auto-restart control + tally.
--   hard_pending=1 -> next auto-restart is HARD (relaunch process; set when fixes staged)
--   restart_now=1  -> SQF scheduler signalled T-0; restart_watchdog.sh relaunches on hard cycles
--   watch_start/until -> restart-count window (owner-connect tally + 10am watchdog report)
CREATE TABLE IF NOT EXISTS `server_control` (
  `id`           TINYINT     NOT NULL DEFAULT 1,
  `hard_pending` TINYINT     NOT NULL DEFAULT 0,
  `restart_now`  TINYINT     NOT NULL DEFAULT 0,
  `watch_start`  DATETIME    NULL,
  `watch_until`  DATETIME    NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS `restart_log` (
  `id`   INT         NOT NULL AUTO_INCREMENT,
  `ts`   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `mode` VARCHAR(8)  NOT NULL DEFAULT 'soft',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Loonybin Exchange (player marketplace -- server APS_fnc_exchangeSystemSRV). Row states: active=1 live listing
-- (pid=seller); active=2 storage row (BuyorSell 1=purchased w/ from_pid=seller, 2=retracted-or-expired). isWeapon
-- doubles as the client's isPhysical flag; timer = hours since listed (expires at 120). Added to the schema-of-record
-- 2026-06-23: the table was created live (post-2026-06-09) and was MISSING here, so a rebuild from this file would
-- silently no-op the entire Exchange.
CREATE TABLE IF NOT EXISTS `exchange` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `ClassName` varchar(255) NOT NULL DEFAULT '',
  `Price` bigint(20) NOT NULL DEFAULT 0,
  `isVirtual` tinyint(4) NOT NULL DEFAULT 0,
  `isWeapon` tinyint(4) NOT NULL DEFAULT 0,
  `isVehicle` tinyint(4) NOT NULL DEFAULT 0,
  `Amount` int(11) NOT NULL DEFAULT 1,
  `pid` varchar(32) NOT NULL DEFAULT '',
  `BuyorSell` tinyint(4) NOT NULL DEFAULT 0,
  `VehicleID` int(11) DEFAULT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `active` tinyint(4) NOT NULL DEFAULT 1,
  `timer` int(11) NOT NULL DEFAULT 0,
  `from_pid` varchar(32) NOT NULL DEFAULT '',
  `bought_at` bigint(20) NOT NULL DEFAULT 0,
  PRIMARY KEY (`ID`),
  KEY `idx_lookup` (`active`,`BuyorSell`,`ClassName`(64))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================================================
-- suites (2026-08-06) -- leased floors of the Skyscraper30 lux tower.
-- Canonical DDL lives in sql/suites.sql; kept here so the documented schema
-- matches live. See suites.md for the design and why this is not `houses`.
-- ============================================================================
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


-- ---------------------------------------------------------------------------
-- OFFLINE MESSAGES (owner 2026-08-12). A text sent to a player who is not on
-- the server is queued here and delivered the next time they are seen online
-- (APS_fnc_offlineMsgDeliver, on a 12s poll from init.sqf). Delivered rows are
-- pruned after seven days. Same DDL as sql/offline_msgs.sql -- kept here too so
-- a fresh database gets it without a separate migration step.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS offline_msgs (
    id        INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    to_uid    VARCHAR(32)  NOT NULL,
    from_uid  VARCHAR(32)  NOT NULL,
    from_name VARCHAR(32)  NOT NULL,
    message   VARCHAR(700) NOT NULL,
    delivered TINYINT      NOT NULL DEFAULT 0,
    ts        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_to (to_uid, delivered, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ---------------------------------------------------------------------------
-- BLACKJACK POWERUP CHIPS (owner 2026-08-12). Same DDL as sql/casino_chips.sql,
-- carried here so a fresh database gets it without a separate migration.
-- ---------------------------------------------------------------------------
-- Armapunk 2035 (owner 2026-08-12): BLACKJACK POWERUP CHIPS.
-- DEALERBOT's table awards consumable chips on money wins (tiered drop, pity guarantee).
-- 26 chip types, no carry cap, so this is a per-player-per-type counter rather than a
-- JSON blob on `players`: an economy item that is EARNED and SPENT wants rows that can be
-- audited and adjusted, not a string that has to be parsed to answer "who has what".
--
-- Composite primary key makes the grant an UPSERT in one statement and makes a spend a
-- guarded decrement -- qty can never go negative, which is the whole anti-dupe story.
--
-- Run on the live DB at deploy, same as sql/talent_points.sql.

CREATE TABLE IF NOT EXISTS casino_chips (
    pid        VARCHAR(32) NOT NULL,
    chip       VARCHAR(24) NOT NULL,          -- chip id, e.g. 'nudge', 'flatline', 'cascade'
    qty        INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (pid, chip),
    KEY idx_pid (pid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Drop-pity counter: how many money wins since this player last received a chip.
-- Kept next to the wallet rather than in memory so the guarantee survives a restart --
-- otherwise every server restart silently resets everyone's pity to zero.
CREATE TABLE IF NOT EXISTS casino_chip_pity (
    pid        VARCHAR(32) NOT NULL PRIMARY KEY,
    dry_wins   INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
