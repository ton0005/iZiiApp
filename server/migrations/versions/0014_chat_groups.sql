-- Migration 0014: chat groups, broadcast channels, and read receipts (Phase 2)
-- Supports group metadata (title, description, avatar, broadcast mode)
-- and per-message read receipts for group conversations.

ALTER TABLE chat_conversations ADD COLUMN title TEXT;
ALTER TABLE chat_conversations ADD COLUMN description TEXT;
ALTER TABLE chat_conversations ADD COLUMN avatar_url TEXT;
ALTER TABLE chat_conversations ADD COLUMN is_broadcast INTEGER DEFAULT 0;

CREATE TABLE IF NOT EXISTS chat_read_receipts (
    conversation_id  TEXT NOT NULL,
    message_id       TEXT NOT NULL,
    member_id        TEXT NOT NULL,
    read_at          TEXT NOT NULL,
    PRIMARY KEY (message_id, member_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_reads_convo ON chat_read_receipts(conversation_id);
