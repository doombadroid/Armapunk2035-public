-- Ben Bones DMs: player texts queued for the bones.py daemon; reply delivered back in-game. Idempotent.
CREATE TABLE IF NOT EXISTS bones_dm (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  uid VARCHAR(32) NOT NULL,
  name VARCHAR(32) NOT NULL,
  message VARCHAR(700) NOT NULL,
  reply VARCHAR(700) DEFAULT NULL,
  delivered TINYINT NOT NULL DEFAULT 0,
  ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_reply (reply(1), delivered),
  KEY idx_uid (uid, id)
);
