-- Community Voting v2 — up/down votes, images, close dates, comment threads.
-- Applied to the live `looneybin` DB (CachyOS box, docker looneybin-db) 2026-07-02.
-- Backup taken to ~/loonybin-website/backup_voting_pre.sql before running.

ALTER TABLE web_feature_requests
  ADD COLUMN image_url VARCHAR(255) NULL AFTER body,
  ADD COLUMN closes_at DATETIME   NULL AFTER status;

ALTER TABLE web_feature_votes
  ADD COLUMN vote TINYINT NOT NULL DEFAULT 1;   -- 1 = upvote, -1 = downvote

CREATE TABLE IF NOT EXISTS web_feature_comments (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  feature_id  INT          NOT NULL,
  author_id   VARCHAR(32)  NOT NULL,
  author_name VARCHAR(64)  NOT NULL,
  body        TEXT         NOT NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_feature (feature_id)
);

-- Uploaded poll images live on disk at  <app cwd>/uploads/voting/<uuid>.<ext>
-- and are served through the route  /api/images/voting/[name]  (not public/).
