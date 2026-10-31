-- ============================================================================
--  web_schema.sql — site-native tables for the LooneyBin stats website.
--  These are SEPARATE from the live game tables (prefixed `web_`). The website
--  reads game data read-only; these hold website-only content (tickets, feature
--  voting, changelogs, wiki). Safe to run against the same `looneybin` DB.
-- ============================================================================
USE `looneybin`;

CREATE TABLE IF NOT EXISTS `web_tickets` (
  `id`          INT          NOT NULL AUTO_INCREMENT,
  `playerid`    VARCHAR(17)  NOT NULL,
  `player_name` VARCHAR(64)  NOT NULL DEFAULT '',
  `subject`     VARCHAR(160) NOT NULL,
  `category`    VARCHAR(32)  NOT NULL DEFAULT 'general',
  `status`      ENUM('open','answered','closed') NOT NULL DEFAULT 'open',
  `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `playerid` (`playerid`),
  KEY `status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `web_ticket_messages` (
  `id`          INT          NOT NULL AUTO_INCREMENT,
  `ticket_id`   INT          NOT NULL,
  `author_id`   VARCHAR(17)  NOT NULL,
  `author_name` VARCHAR(64)  NOT NULL DEFAULT '',
  `is_staff`    TINYINT(1)   NOT NULL DEFAULT 0,
  `body`        TEXT         NOT NULL,
  `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `ticket_id` (`ticket_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `web_feature_requests` (
  `id`          INT          NOT NULL AUTO_INCREMENT,
  `playerid`    VARCHAR(17)  NOT NULL,
  `author_name` VARCHAR(64)  NOT NULL DEFAULT '',
  `title`       VARCHAR(160) NOT NULL,
  `body`        TEXT,
  `status`      ENUM('open','planned','done','declined') NOT NULL DEFAULT 'open',
  `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `web_feature_votes` (
  `feature_id` INT         NOT NULL,
  `playerid`   VARCHAR(17) NOT NULL,
  `created_at` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`feature_id`,`playerid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `web_changelogs` (
  `id`          INT          NOT NULL AUTO_INCREMENT,
  `version`     VARCHAR(32)  NOT NULL DEFAULT '',
  `title`       VARCHAR(160) NOT NULL,
  `body`        MEDIUMTEXT,
  `author_name` VARCHAR(64)  NOT NULL DEFAULT '',
  `published`   TINYINT(1)   NOT NULL DEFAULT 1,
  `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `web_wiki_pages` (
  `id`         INT          NOT NULL AUTO_INCREMENT,
  `slug`       VARCHAR(96)  NOT NULL,
  `title`      VARCHAR(160) NOT NULL,
  `category`   VARCHAR(48)  NOT NULL DEFAULT 'General',
  `body`       MEDIUMTEXT,
  `updated_by` VARCHAR(64)  NOT NULL DEFAULT '',
  `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `slug` (`slug`),
  KEY `category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
