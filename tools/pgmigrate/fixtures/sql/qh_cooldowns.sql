-- Server-owned, persistent cooldown for the Detonate quickhack.
--
-- Every other quickhack keys its cooldown off diag_tickTime in the CLIENT's missionNamespace
-- (fn_qhCast), which fn_qhSRV never checks. That is survivable for an 18-minute non-lethal hack and
-- not survivable for Detonate: a 2-hour gate that a relog clears is not a gate. This column is the
-- durable half of the fix -- the server stamps an expiry here and refuses an early cast against it,
-- so the cooldown outlives both a reconnect and a scheduled restart.
--
-- DATETIME rather than an epoch integer on purpose: the DATABASE owns the clock. The server never does
-- date arithmetic in SQF (there is no clean epoch in Arma, and serverTime resets every restart) -- it
-- writes DATE_ADD(NOW(), INTERVAL ...) and reads TIMESTAMPDIFF(...NOW()...), so both sides of every
-- comparison come from the same NOW() and the box/DB timezone split (box America/Chicago, DB UTC)
-- cannot skew it.
--
-- Deliberately one column for one hack. If a second hack ever needs a real cooldown, generalise this
-- into a `qh_cooldowns(playerid, hackid, expires_at)` table rather than adding a second column.
--
-- Apply to BOTH schemas before deploying the Detonate build. Idempotent.

ALTER TABLE players
    ADD COLUMN IF NOT EXISTS qh_detonate_cd DATETIME NULL DEFAULT NULL;
