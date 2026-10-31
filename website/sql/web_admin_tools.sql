-- Admin edit tools + faction blacklist. Applied to live `looneybin` DB 2026-07-02.

-- audit trail for economy/progression edits (money, vehicles, gang funds)
CREATE TABLE IF NOT EXISTS web_admin_log (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  ts          TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actor_id    VARCHAR(32) NOT NULL,
  actor_name  VARCHAR(64) NOT NULL,
  target_id   VARCHAR(32) NULL,
  target_name VARCHAR(64) NULL,
  action      VARCHAR(48) NOT NULL,   -- e.g. money.cash | vehicle.add | gang.bank
  detail      VARCHAR(255) NULL,
  INDEX idx_target (target_id), INDEX idx_ts (ts)
);

-- per-faction blacklist (bars a player from being whitelisted into that faction)
CREATE TABLE IF NOT EXISTS web_faction_blacklist (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  faction       VARCHAR(16) NOT NULL,   -- police | medic
  playerid      VARCHAR(32) NOT NULL,
  name          VARCHAR(64) NULL,
  reason        VARCHAR(255) NULL,
  added_by      VARCHAR(32) NOT NULL,
  added_by_name VARCHAR(64) NOT NULL,
  created_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  removed_at    DATETIME    NULL,       -- soft-delete = still queryable history
  INDEX idx_fac (faction), INDEX idx_pid (playerid)
);

-- Permission: economy edits = adminlevel>=3 (Admin) or Owner. Faction ranks keep
-- whitelister rules; server rank (adminlevel) is owner-only. Blacklist = faction
-- command or admin. Website adminlevel label 4 renamed Developer -> Senior Admin.
