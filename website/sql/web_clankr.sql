-- CLANKR anti-cheat alert mirror. clankr.py writes every detection here (in
-- addition to the Discord outbox) so the website can show a live CLANKR feed.
USE `looneybin`;

CREATE TABLE IF NOT EXISTS `clankr_alerts` (
  `id`       INT          NOT NULL AUTO_INCREMENT,
  `ts`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,  -- when CLANKR flagged
  `severity` VARCHAR(8)   NOT NULL DEFAULT 'MED',              -- LOW|MED|HIGH
  `rule`     VARCHAR(64)  NOT NULL DEFAULT '',
  `playerid` VARCHAR(17)  NOT NULL DEFAULT '',
  `name`     VARCHAR(64)  NOT NULL DEFAULT '',
  `detail`   TEXT,
  `snippet`  TEXT,
  `event_ts` VARCHAR(40)  NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `ts` (`ts`),
  KEY `playerid` (`playerid`),
  KEY `severity` (`severity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
