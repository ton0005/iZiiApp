-- Migration 0013: chat conversation registry + membership
-- Lets the server route WS /chat events and filter /sync/pull chat rows to
-- conversation members only (see chat_access.py).
-- SQLite creates the same objects in db_init.py.

CREATE TABLE IF NOT EXISTS chat_conversations (
    id           TEXT PRIMARY KEY,
    type         TEXT NOT NULL,
    record_type  TEXT,
    record_id    TEXT,
    created_by   TEXT,
    created_at   TEXT NOT NULL,
    updated_at   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS chat_conversation_members (
    conversation_id  TEXT NOT NULL,
    member_id        TEXT NOT NULL,
    role             TEXT NOT NULL DEFAULT 'member',
    joined_at        TEXT NOT NULL,
    left_at          TEXT,
    PRIMARY KEY (conversation_id, member_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_members_member ON chat_conversation_members(member_id);
