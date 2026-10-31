-- Armapunk Pixel v3 migration: the v2 tables go (the save format, the market key column and the
-- feed changed; the closed test has one player and the reference balance replaces the v2 rename
-- layer). Run this, then web_pixel.sql. Applied on .96 as armapunk.
--   docker exec -i armapunk-pg psql -U armapunk -d armapunk -v ON_ERROR_STOP=1 < website/sql/pg/web_pixel_v3.sql
--   docker exec -i armapunk-pg psql -U armapunk -d armapunk -v ON_ERROR_STOP=1 < website/sql/pg/web_pixel.sql
DROP TABLE IF EXISTS web_pixel_events;
DROP TABLE IF EXISTS web_pixel_market;
DROP TABLE IF EXISTS web_pixel_players;
