-- HUD UI EDITOR (hudeditor.md) -- per-account status-HUD layout.
--
-- players_global, not players: a HUD layout is an ACCOUNT preference and has to follow the
-- player across civ / cop / medic and every character. players_global is already the
-- account-scope table (achievements, stats, keys, mailbox).
--
-- Shape: an array of arrays of NUMBERS, seven pairs, in the handle order of hudeditor.md §1
--
--   [ group, hp, h2o, food, wanted, chips, minimap ]
--
-- each [dx, dy] a viewport fraction in [-1, 1]. Numbers only, no object keys -- that is what
-- lets the client read it back with parseSimpleArray and never call compile (the rule at
-- server/AP_server/core/DB/fn_queryRequest.sqf:40, Lystic compile-RCE class).
--
-- NULL means "never edited" and the client reads it as seven zero pairs, i.e. the designer's
-- shipped layout. That is also the failure mode on any DB error, which is the safe direction.

ALTER TABLE players_global ADD COLUMN IF NOT EXISTS ui_layout jsonb DEFAULT NULL;
