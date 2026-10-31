-- LooneyBin (owner 2026-07-16): BUYABLE TALENT POINTS.
-- Players purchase extra talent points past the free cap (1st = $1.0m, then +$500k each) until every talent
-- in their tree is learnable. One row per player; `points` = how many they've bought (all sides share it).
-- Run on the live DB (schema `looneybin`) at deploy, same as sql/mining.sql.

CREATE TABLE IF NOT EXISTS talent_points (
    pid        VARCHAR(32) NOT NULL PRIMARY KEY,
    points     INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
