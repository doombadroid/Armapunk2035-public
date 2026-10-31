-- Looner 2.0: likes + reply threading + verified badges (owner/governor/Ben Bones bot). Idempotent.
ALTER TABLE looner_posts ADD COLUMN IF NOT EXISTS likes INT NOT NULL DEFAULT 0;
ALTER TABLE looner_posts ADD COLUMN IF NOT EXISTS reply_to INT NOT NULL DEFAULT 0;
ALTER TABLE looner_posts ADD COLUMN IF NOT EXISTS verified TINYINT NOT NULL DEFAULT 0;
CREATE TABLE IF NOT EXISTS looner_likes (
  uid VARCHAR(32) NOT NULL,
  post_id INT NOT NULL,
  PRIMARY KEY (uid, post_id)
);
