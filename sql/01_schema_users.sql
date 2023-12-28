CREATE TABLE IF NOT EXISTS "user" (
    telegram_id INTEGER,
    last_seen_epoch INTEGER DEFAULT NULL,
    activity_counter INTEGER DEFAULT 0,
    PRIMARY KEY (telegram_id)
);