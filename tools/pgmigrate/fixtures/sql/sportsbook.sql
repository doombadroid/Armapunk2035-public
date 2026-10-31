-- LoonyBets sportsbook: parimutuel YES/NO bets on server events. Bets settle per market window.
CREATE TABLE IF NOT EXISTS sportsbook_bets (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  uid VARCHAR(32) NOT NULL,
  name VARCHAR(32) NOT NULL,
  market_key VARCHAR(24) NOT NULL,
  selection VARCHAR(4) NOT NULL,
  stake INT NOT NULL DEFAULT 0,
  status VARCHAR(8) NOT NULL DEFAULT 'open',
  ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_mk (market_key, status)
);
