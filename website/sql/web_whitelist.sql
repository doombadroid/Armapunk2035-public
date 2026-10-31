-- ============================================================================
--  web_whitelist.sql — faction whitelist audit log (site-native).
--  The whitelist itself writes the GAME columns players_global.coplevel /
--  mediclevel (the in-game source of truth). This table is the audit trail.
-- ============================================================================
USE `looneybin`;

CREATE TABLE IF NOT EXISTS `web_whitelist_log` (
  `id`         INT          NOT NULL AUTO_INCREMENT,
  `ts`         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `faction`    VARCHAR(24)  NOT NULL,             -- 'police' | 'medic' | ...
  `actor_id`   VARCHAR(17)  NOT NULL,
  `actor_name` VARCHAR(64)  NOT NULL DEFAULT '',
  `actor_role` VARCHAR(64)  NOT NULL DEFAULT '',  -- e.g. "MaxSec Lieutenant" / "Admin L5" / "Owner"
  `target_id`  VARCHAR(17)  NOT NULL,
  `target_name` VARCHAR(64) NOT NULL DEFAULT '',
  `old_rank`   INT          NOT NULL DEFAULT 0,
  `new_rank`   INT          NOT NULL DEFAULT 0,
  `action`     VARCHAR(16)  NOT NULL DEFAULT 'set', -- whitelist|promote|demote|remove
  PRIMARY KEY (`id`),
  KEY `faction` (`faction`),
  KEY `ts` (`ts`),
  KEY `target_id` (`target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
