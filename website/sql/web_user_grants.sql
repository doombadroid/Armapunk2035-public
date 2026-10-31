-- Least-privilege MySQL user for the website (recommended for production).
-- The site reads ALL game tables but only WRITES the site-native web_* tables.
-- Run as root, then set DB_USER/DB_PASSWORD in the website .env.local to match.

CREATE USER IF NOT EXISTS 'looneybin_web'@'127.0.0.1' IDENTIFIED BY 'CHANGE_ME_STRONG_PASSWORD';

-- read-only across the whole game DB
GRANT SELECT ON `looneybin`.* TO 'looneybin_web'@'127.0.0.1';

-- read/write only on the website's own tables
GRANT SELECT, INSERT, UPDATE, DELETE ON `looneybin`.`web_tickets`          TO 'looneybin_web'@'127.0.0.1';
GRANT SELECT, INSERT, UPDATE, DELETE ON `looneybin`.`web_ticket_messages`  TO 'looneybin_web'@'127.0.0.1';
GRANT SELECT, INSERT, UPDATE, DELETE ON `looneybin`.`web_feature_requests` TO 'looneybin_web'@'127.0.0.1';
GRANT SELECT, INSERT, UPDATE, DELETE ON `looneybin`.`web_feature_votes`    TO 'looneybin_web'@'127.0.0.1';
GRANT SELECT, INSERT, UPDATE, DELETE ON `looneybin`.`web_changelogs`       TO 'looneybin_web'@'127.0.0.1';
GRANT SELECT, INSERT, UPDATE, DELETE ON `looneybin`.`web_wiki_pages`       TO 'looneybin_web'@'127.0.0.1';
GRANT SELECT, INSERT, UPDATE, DELETE ON `looneybin`.`web_whitelist_log`    TO 'looneybin_web'@'127.0.0.1';

-- faction whitelisting writes ONLY these game columns: ranks (players_global) +
-- sub-whitelist flags MaxTac/SCD (players).
-- adminlevel = the owner-only Server Staff whitelist (rank assignment).
GRANT UPDATE (`coplevel`, `mediclevel`, `adminlevel`) ON `looneybin`.`players_global` TO 'looneybin_web'@'127.0.0.1';
GRANT UPDATE (`ismaxtac`, `isscd`)  ON `looneybin`.`players`        TO 'looneybin_web'@'127.0.0.1';

-- moderation: issue/lift bans (-> in-game enforce + CLANKR BattleMetrics mirror) + kick bridge.
GRANT SELECT, INSERT, UPDATE ON `looneybin`.`bans`         TO 'looneybin_web'@'127.0.0.1';
GRANT INSERT             ON `looneybin`.`bot_commands`    TO 'looneybin_web'@'127.0.0.1';
GRANT SELECT, INSERT, UPDATE, DELETE ON `looneybin`.`web_vpn_exempt` TO 'looneybin_web'@'127.0.0.1';
-- clankr_alerts is read via the blanket SELECT grant above.

FLUSH PRIVILEGES;
