-- ============================================================================
-- LooneyBin — DEV DATABASE SCHEMA (game server only)
-- Generated from the live DB structure 2026-06-26.
--
-- Includes EVERY table the Arma server / @AP_server queries, so a dev server
-- loads with NO missing-table errors -- including bot_commands, log, restart_log
-- (the GAME polls/writes these; they are NOT optional).
--
-- EXCLUDES (none of the bot stuff): website tables (web_*), Discord-bot-only
-- tables (enrique_log = Enrique gardener, maxsec_applications = Officer Maggot),
-- and DB backups (_backup_*).
--
-- Usage:
--   CREATE DATABASE looneybin;
--   mariadb -u<user> -p<pass> looneybin < looneybin_dev_schema.sql
--
-- Player/world tables are created EMPTY. Only the small control/state tables
-- (server_control, config, gangfort, turf_state, cartel_state) are seeded so a
-- fresh server boots cleanly.
-- ============================================================================

SET FOREIGN_KEY_CHECKS=0;

/*M!999999\- enable the sandbox mode */ 

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*M!100616 SET @OLD_NOTE_VERBOSITY=@@NOTE_VERBOSITY, NOTE_VERBOSITY=0 */;
DROP TABLE IF EXISTS `bans`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `bans` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `playerid` varchar(17) NOT NULL,
  `reason` text DEFAULT NULL,
  `banned_by` varchar(40) DEFAULT NULL,
  `until` datetime DEFAULT NULL,
  `created` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `ix_pid` (`playerid`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `bot_commands`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `bot_commands` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `command` varchar(16) NOT NULL,
  `target` varchar(17) DEFAULT NULL,
  `arg1` varchar(255) DEFAULT NULL,
  `arg2` text DEFAULT NULL,
  `issued_by` varchar(40) DEFAULT NULL,
  `status` varchar(12) NOT NULL DEFAULT 'pending',
  `created` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `ix_status` (`status`)
) ENGINE=InnoDB AUTO_INCREMENT=740 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `bounties`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `bounties` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `target_uid` varchar(17) NOT NULL,
  `target_name` varchar(64) NOT NULL,
  `amount` bigint(20) NOT NULL DEFAULT 0,
  `placed_by` varchar(17) DEFAULT NULL,
  `insert_time` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `target_uid` (`target_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `candidates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `candidates` (
  `playerid` varchar(20) NOT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `policy` text DEFAULT NULL,
  `investment` bigint(20) NOT NULL DEFAULT 0,
  `started_at` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`playerid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `captures`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `captures` (
  `id` int(11) NOT NULL,
  `gang` int(11) DEFAULT NULL,
  `percent` int(11) NOT NULL DEFAULT 0,
  `container` text DEFAULT NULL,
  `level` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `cartel_state`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `cartel_state` (
  `cartel` varchar(16) NOT NULL,
  `gang_id` varchar(32) DEFAULT NULL,
  `progress` double DEFAULT NULL,
  `updated` datetime DEFAULT NULL,
  PRIMARY KEY (`cartel`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `config`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `config` (
  `index` int(11) NOT NULL,
  `value` text DEFAULT NULL,
  PRIMARY KEY (`index`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `discord_links`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `discord_links` (
  `discord_id` bigint(20) unsigned NOT NULL,
  `playerid` varchar(20) NOT NULL,
  `reward_pending` tinyint(4) NOT NULL DEFAULT 0,
  `linked_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `beta_pending` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`discord_id`),
  UNIQUE KEY `uniq_pid` (`playerid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `exchange`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `exchange` (
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
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `foreskins`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `foreskins` (
  `uid` varchar(32) NOT NULL,
  `name` varchar(64) NOT NULL DEFAULT 'Unknown',
  `first_harvested` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `gang_bank_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `gang_bank_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gangid` int(11) NOT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `uid` varchar(17) NOT NULL DEFAULT '',
  `type` tinyint(4) NOT NULL,
  `amount` bigint(20) NOT NULL,
  `ts` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_gang` (`gangid`,`id`)
) ENGINE=InnoDB AUTO_INCREMENT=279 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `gang_vehicles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `gang_vehicles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `pid` varchar(17) NOT NULL,
  `classname` varchar(64) NOT NULL,
  `type` varchar(16) NOT NULL DEFAULT 'Car',
  `gang_id` int(11) NOT NULL,
  `inventory` text DEFAULT NULL,
  `active` tinyint(1) NOT NULL DEFAULT 0,
  `plate` int(11) NOT NULL DEFAULT 0,
  `color` int(11) NOT NULL DEFAULT 0,
  `fuel` int(11) NOT NULL DEFAULT 100,
  `damage` int(11) NOT NULL DEFAULT 0,
  `alarm` tinyint(1) NOT NULL DEFAULT 0,
  `mods` text DEFAULT NULL,
  `insert_time` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_gang_plate` (`gang_id`,`plate`),
  KEY `gang_id` (`gang_id`,`active`,`type`)
) ENGINE=InnoDB AUTO_INCREMENT=129 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `gangfort`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `gangfort` (
  `id` tinyint(4) NOT NULL DEFAULT 1,
  `active` tinyint(4) DEFAULT 0,
  `ends` bigint(20) DEFAULT 0,
  `winner_id` int(11) DEFAULT -1,
  `winner_name` varchar(64) DEFAULT '',
  `leaderboard` text DEFAULT NULL,
  `updated` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `last_auto` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `gangs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `gangs` (
  `id` int(11) NOT NULL,
  `name` varchar(32) NOT NULL,
  `wars` text DEFAULT NULL,
  `inviterank` int(11) NOT NULL DEFAULT 2,
  `kickrank` int(11) NOT NULL DEFAULT 2,
  `bank` bigint(20) NOT NULL DEFAULT 0,
  `experience` bigint(20) NOT NULL DEFAULT 0,
  `talents` text DEFAULT NULL,
  `instance` int(11) NOT NULL DEFAULT 0,
  `house_pos` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `gov_state`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `gov_state` (
  `id` int(11) NOT NULL,
  `playerid` varchar(20) NOT NULL DEFAULT '',
  `name` varchar(64) NOT NULL DEFAULT '',
  `tax` int(11) NOT NULL DEFAULT 0,
  `weedlegal` tinyint(4) NOT NULL DEFAULT 0,
  `sparlegal` tinyint(4) NOT NULL DEFAULT 0,
  `deathpen` tinyint(4) NOT NULL DEFAULT 0,
  `elected_at` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `houses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `houses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `oid` varchar(32) NOT NULL,
  `owners` varchar(17) NOT NULL,
  `locked` tinyint(1) NOT NULL DEFAULT 1,
  `worldspace` text NOT NULL,
  `sale` bigint(20) NOT NULL DEFAULT 0,
  `instance` int(11) NOT NULL DEFAULT 0,
  `vcap` int(11) NOT NULL DEFAULT 0,
  `phys_cap` int(11) NOT NULL DEFAULT 0,
  `keycap` int(11) NOT NULL DEFAULT 0,
  `barrel` tinyint(4) NOT NULL DEFAULT 0,
  `greenhouse` tinyint(4) NOT NULL DEFAULT 0,
  `leadcontainer` tinyint(4) NOT NULL DEFAULT 0,
  `keyholders` text DEFAULT NULL,
  `vinv` text DEFAULT NULL,
  `pinv` text DEFAULT NULL,
  `tax_playtime` int(11) NOT NULL DEFAULT 0,
  `tax_paid` timestamp NOT NULL DEFAULT current_timestamp(),
  `furniture` text DEFAULT NULL,
  `greenhouse_crop` text DEFAULT NULL,
  `barrel_crop` text DEFAULT NULL,
  `classname` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `oid_UNIQUE` (`oid`),
  KEY `owners` (`owners`),
  KEY `worldspace` (`worldspace`(64))
) ENGINE=InnoDB AUTO_INCREMENT=622 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `itemstock`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `itemstock` (
  `className` varchar(64) NOT NULL,
  `quantity` double NOT NULL DEFAULT 1,
  `sales` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`className`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `loadouts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `loadouts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `pid` varchar(17) NOT NULL,
  `side` varchar(8) NOT NULL,
  `slot` int(11) NOT NULL DEFAULT 0,
  `name` varchar(64) DEFAULT NULL,
  `gear` text DEFAULT NULL,
  `currency` varchar(16) NOT NULL DEFAULT 'cash',
  PRIMARY KEY (`id`),
  KEY `pid_side` (`pid`,`side`)
) ENGINE=InnoDB AUTO_INCREMENT=525 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `log` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `ts` timestamp NOT NULL DEFAULT current_timestamp(),
  `tag` varchar(32) NOT NULL DEFAULT '',
  `playerid` varchar(17) NOT NULL DEFAULT '',
  `name` varchar(64) NOT NULL DEFAULT '',
  `message` text DEFAULT NULL,
  `instance` int(11) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `idx_tag_ts` (`tag`,`ts`),
  KEY `idx_pid_ts` (`playerid`,`ts`)
) ENGINE=InnoDB AUTO_INCREMENT=1385120 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `online`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `online` (
  `playerid` varchar(17) NOT NULL,
  `name` varchar(64) DEFAULT NULL,
  `instance` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`playerid`,`instance`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `opfor_whitelist`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `opfor_whitelist` (
  `playerid` varchar(17) NOT NULL,
  `name` varchar(64) DEFAULT '',
  `opforlevel` tinyint(2) NOT NULL DEFAULT 0,
  `opforretired` tinyint(2) NOT NULL DEFAULT 0,
  `added` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`playerid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='4th faction (OPFOR) whitelist - mirrors cop coplevel/copretired; no ranks set yet (teaser)';
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `player_names`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `player_names` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `playerid` varchar(17) NOT NULL,
  `name` varchar(64) NOT NULL,
  `seen` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pid_name` (`playerid`,`name`),
  KEY `k_pid_seen` (`playerid`,`seen`)
) ENGINE=InnoDB AUTO_INCREMENT=6123 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `players`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `players` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `playerid` varchar(17) NOT NULL,
  `name` varchar(64) NOT NULL DEFAULT 'Error',
  `aliases` text DEFAULT NULL,
  `instance` int(11) NOT NULL DEFAULT 0,
  `cash` bigint(20) NOT NULL DEFAULT 0,
  `bankacc` bigint(20) NOT NULL DEFAULT 50000,
  `new_drachma` decimal(20,4) NOT NULL DEFAULT 0,
  `civ_gear` text DEFAULT NULL,
  `cop_gear` text DEFAULT NULL,
  `med_gear` text DEFAULT NULL,
  `civ_licenses` text DEFAULT NULL,
  `cop_licenses` text DEFAULT NULL,
  `med_licenses` text DEFAULT NULL,
  `civ_talents` text DEFAULT NULL,
  `cop_talents` text DEFAULT NULL,
  `med_talents` text DEFAULT NULL,
  `civ_exp` bigint(20) NOT NULL DEFAULT 100,
  `cop_exp` bigint(20) NOT NULL DEFAULT 0,
  `med_exp` bigint(20) NOT NULL DEFAULT 0,
  `prestige` text DEFAULT NULL,
  `infamy_exp` bigint(20) NOT NULL DEFAULT 0,
  `infamy_talents` text DEFAULT NULL,
  `arrested` text DEFAULT NULL,
  `crimes` text DEFAULT NULL,
  `position` text DEFAULT NULL,
  `gov_data` text DEFAULT NULL,
  -- completed_quests/progress_quests dropped, task 11 (sql/drop_legacy_quest_columns.sql) -- applied to this dev schema
  `title` int(11) NOT NULL DEFAULT -1,
  `prefix` varchar(32) NOT NULL DEFAULT '',
  `ismaxtac` tinyint(1) NOT NULL DEFAULT 0,
  `isfirefighter` tinyint(1) NOT NULL DEFAULT 0,
  `gang0` int(11) DEFAULT NULL,
  `gangrank0` int(11) NOT NULL DEFAULT 5,
  `alive` tinyint(1) NOT NULL DEFAULT 1,
  `damage` double NOT NULL DEFAULT 0,
  `thirst` double NOT NULL DEFAULT 100,
  `hunger` double NOT NULL DEFAULT 100,
  `new_player` tinyint(1) NOT NULL DEFAULT 1,
  `lastupdated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `medic_prestige` bigint(20) NOT NULL DEFAULT 0,
  `medic_talents` text DEFAULT NULL,
  `pre_talents` text DEFAULT NULL,
  `lb_days` int(11) NOT NULL DEFAULT 0,
  `lb_claimed` tinyint(4) NOT NULL DEFAULT 0,
  `lb_last` date DEFAULT NULL,
  `drone_revives` int(11) NOT NULL DEFAULT 5,
  `drone_support` int(11) NOT NULL DEFAULT 10,
  `drone_recharge_until` bigint(20) NOT NULL DEFAULT 0,
  `xmas_last` date DEFAULT NULL,
  `isscd` tinyint(1) NOT NULL DEFAULT 0,
  `casino_banned` tinyint(1) NOT NULL DEFAULT 0,
  `wheel_last_free` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `playerid` (`playerid`),
  KEY `gang0` (`gang0`)
) ENGINE=InnoDB AUTO_INCREMENT=542 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `players_global`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `players_global` (
  `playerid` varchar(17) NOT NULL,
  `adminlevel` tinyint(2) NOT NULL DEFAULT 0,
  `eventcoordinatorlvl` tinyint(2) NOT NULL DEFAULT 0,
  `coplevel` tinyint(2) NOT NULL DEFAULT 0,
  `copretired` tinyint(2) NOT NULL DEFAULT 0,
  `mediclevel` tinyint(2) NOT NULL DEFAULT 0,
  `achievements` text DEFAULT NULL,
  `stats` text DEFAULT NULL,
  `honor_exp` bigint(20) NOT NULL DEFAULT 0,
  `honor_talents` text DEFAULT NULL,
  `lootrewards` text DEFAULT NULL,
  `keys` text DEFAULT NULL,
  `wealth` bigint(20) NOT NULL DEFAULT 0,
  `mailbox` text DEFAULT NULL,
  `betatester` tinyint(1) NOT NULL DEFAULT 0,
  `lifetime_stats` text DEFAULT NULL,
  PRIMARY KEY (`playerid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `price_overrides`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `price_overrides` (
  `family` varchar(16) NOT NULL,
  `item_key` varchar(128) NOT NULL,
  `p0` int(11) DEFAULT -1,
  `p1` int(11) DEFAULT -1,
  `p2` int(11) DEFAULT -1,
  `display_name` varchar(128) DEFAULT '',
  `updated_by` varchar(40) DEFAULT '',
  `updated` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`family`,`item_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `refund_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `refund_log` (
  `playerid` varchar(17) NOT NULL,
  `name` varchar(64) DEFAULT NULL,
  `amount` bigint(20) DEFAULT NULL,
  `old_bank` bigint(20) DEFAULT NULL,
  `new_bank` bigint(20) DEFAULT NULL,
  `reason` varchar(128) DEFAULT NULL,
  `refunded_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`playerid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `restart_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `restart_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ts` datetime NOT NULL DEFAULT current_timestamp(),
  `mode` varchar(8) NOT NULL DEFAULT 'soft',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=71 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `server_control`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `server_control` (
  `id` tinyint(4) NOT NULL DEFAULT 1,
  `hard_pending` tinyint(4) NOT NULL DEFAULT 0,
  `restart_now` tinyint(4) NOT NULL DEFAULT 0,
  `watch_start` datetime DEFAULT NULL,
  `watch_until` datetime DEFAULT NULL,
  `stimmy` tinyint(4) NOT NULL DEFAULT 0,
  `fedoverride` tinyint(4) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `storage`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `storage` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `houseid` int(11) NOT NULL,
  `worldspace` text DEFAULT NULL,
  `container` int(11) NOT NULL DEFAULT -1,
  `classname` varchar(64) NOT NULL,
  `contents` text DEFAULT NULL,
  `virtual` text DEFAULT NULL,
  `houseworldspace` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `houseid` (`houseid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `turf`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `turf` (
  `id` int(11) NOT NULL,
  `gang` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `turf_state`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `turf_state` (
  `id` tinyint(4) NOT NULL DEFAULT 1,
  `active_idx` int(11) DEFAULT -1,
  `ends` bigint(20) DEFAULT 0,
  `updated` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `vehicle_mem`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `vehicle_mem` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `plate` int(11) NOT NULL,
  `worldspace` text DEFAULT NULL,
  `dir` double NOT NULL DEFAULT 0,
  `inventory` text DEFAULT NULL,
  `info_owners` text DEFAULT NULL,
  `dbInfo` text DEFAULT NULL,
  `fuel` int(11) NOT NULL DEFAULT 100,
  `damage` int(11) NOT NULL DEFAULT 0,
  `class` varchar(64) DEFAULT NULL,
  `insured` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `plate` (`plate`)
) ENGINE=InnoDB AUTO_INCREMENT=33554 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `vehicles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `vehicles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `side` varchar(8) NOT NULL,
  `classname` varchar(64) NOT NULL,
  `type` varchar(16) NOT NULL,
  `pid` varchar(17) NOT NULL,
  `alive` tinyint(1) NOT NULL DEFAULT 1,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `listed` tinyint(1) NOT NULL DEFAULT 0,
  `inventory` text DEFAULT NULL,
  `color` int(11) NOT NULL DEFAULT 0,
  `plate` int(11) NOT NULL DEFAULT 0,
  `fuel` int(11) NOT NULL DEFAULT 100,
  `damage` int(11) NOT NULL DEFAULT 0,
  `alarm` tinyint(1) NOT NULL DEFAULT 0,
  `ammo` int(11) NOT NULL DEFAULT 0,
  `mods` text DEFAULT NULL,
  `customplate` varchar(16) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `pid` (`pid`),
  KEY `lookup` (`pid`,`alive`,`active`,`side`,`type`,`listed`)
) ENGINE=InnoDB AUTO_INCREMENT=3172 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `votes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `votes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `playerid` varchar(17) NOT NULL,
  `candidate` varchar(17) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_voter` (`playerid`),
  KEY `playerid` (`playerid`)
) ENGINE=InnoDB AUTO_INCREMENT=56 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `wanted`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `wanted` (
  `playerid` varchar(17) NOT NULL,
  `name` varchar(64) NOT NULL,
  `crimes` text DEFAULT NULL,
  `bounty` bigint(20) NOT NULL DEFAULT 0,
  `jail` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`playerid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `wars`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `wars` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gang1` int(11) NOT NULL,
  `gang2` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_gang1` (`gang1`),
  KEY `idx_gang2` (`gang2`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*M!100616 SET NOTE_VERBOSITY=@OLD_NOTE_VERBOSITY */;


-- ===== seed: control/state rows for a clean first boot =====
/*M!999999\- enable the sandbox mode */ 

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*M!100616 SET @OLD_NOTE_VERBOSITY=@@NOTE_VERBOSITY, NOTE_VERBOSITY=0 */;

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `server_control` WRITE;
/*!40000 ALTER TABLE `server_control` DISABLE KEYS */;
INSERT INTO `server_control` (`id`, `hard_pending`, `restart_now`, `watch_start`, `watch_until`, `stimmy`, `fedoverride`) VALUES (1,0,0,'2026-06-13 06:08:16','2026-06-14 10:00:00',0,0);
/*!40000 ALTER TABLE `server_control` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `config` WRITE;
/*!40000 ALTER TABLE `config` DISABLE KEYS */;
INSERT INTO `config` (`index`, `value`) VALUES (0,'0');
INSERT INTO `config` (`index`, `value`) VALUES (1,'0');
INSERT INTO `config` (`index`, `value`) VALUES (2,'0');
INSERT INTO `config` (`index`, `value`) VALUES (3,'0');
INSERT INTO `config` (`index`, `value`) VALUES (4,'0');
INSERT INTO `config` (`index`, `value`) VALUES (5,'0');
INSERT INTO `config` (`index`, `value`) VALUES (6,'0');
INSERT INTO `config` (`index`, `value`) VALUES (7,'0');
INSERT INTO `config` (`index`, `value`) VALUES (8,'47');
INSERT INTO `config` (`index`, `value`) VALUES (9,'0');
INSERT INTO `config` (`index`, `value`) VALUES (10,'0');
INSERT INTO `config` (`index`, `value`) VALUES (200,'0');
/*!40000 ALTER TABLE `config` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `gangfort` WRITE;
/*!40000 ALTER TABLE `gangfort` DISABLE KEYS */;
INSERT INTO `gangfort` (`id`, `active`, `ends`, `winner_id`, `winner_name`, `leaderboard`, `updated`, `last_auto`) VALUES (1,0,1782340000,50006,'WANGHAF','\"[[50006,``WANGHAF``,4945],[50011,``Retards R Us``,365]]\"','2026-06-24 23:00:11',1782340000);
/*!40000 ALTER TABLE `gangfort` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `turf_state` WRITE;
/*!40000 ALTER TABLE `turf_state` DISABLE KEYS */;
INSERT INTO `turf_state` (`id`, `active_idx`, `ends`, `updated`) VALUES (1,0,1782510000,'2026-06-26 22:16:11');
/*!40000 ALTER TABLE `turf_state` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `cartel_state` WRITE;
/*!40000 ALTER TABLE `cartel_state` DISABLE KEYS */;
INSERT INTO `cartel_state` (`cartel`, `gang_id`, `progress`, `updated`) VALUES ('arms','9',0.716667,'2026-06-26 22:23:32');
INSERT INTO `cartel_state` (`cartel`, `gang_id`, `progress`, `updated`) VALUES ('drug','50015',1,'2026-06-26 21:55:32');
INSERT INTO `cartel_state` (`cartel`, `gang_id`, `progress`, `updated`) VALUES ('oil','50012',1,'2026-06-26 20:55:31');
INSERT INTO `cartel_state` (`cartel`, `gang_id`, `progress`, `updated`) VALUES ('wongs','0',0.483333,'2026-06-26 22:06:32');
/*!40000 ALTER TABLE `cartel_state` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*M!100616 SET NOTE_VERBOSITY=@OLD_NOTE_VERBOSITY */;


SET FOREIGN_KEY_CHECKS=1;
