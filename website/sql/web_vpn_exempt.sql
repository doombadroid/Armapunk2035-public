-- VPN exemption list. BattleMetrics does VPN detection + enforcement via a Trigger;
-- the exemption is a BM player flag the trigger skips. This table is the local
-- management record / audit; BM holds the actual flag (see src/lib/bm.ts).
USE `looneybin`;
CREATE TABLE IF NOT EXISTS `web_vpn_exempt` (
  `id`           INT          NOT NULL AUTO_INCREMENT,
  `playerid`     VARCHAR(17)  NOT NULL,
  `name`         VARCHAR(64)  NOT NULL DEFAULT '',
  `note`         VARCHAR(255) NOT NULL DEFAULT '',
  `added_by`     VARCHAR(64)  NOT NULL DEFAULT '',
  `bm_player_id` VARCHAR(32)  NOT NULL DEFAULT '',
  `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `playerid` (`playerid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
