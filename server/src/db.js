import Database from 'better-sqlite3';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DB_PATH = process.env.DB_PATH || path.join(__dirname, '..', 'data', 'famil.db');

import fs from 'node:fs';
fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });

export const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    display_name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'member',
    room_id TEXT,
    is_online INTEGER NOT NULL DEFAULT 0,
    access_open INTEGER NOT NULL DEFAULT 1,
    is_sleeping INTEGER NOT NULL DEFAULT 0,
    sleep_started_at TEXT,
    sleep_music_enabled INTEGER NOT NULL DEFAULT 1,
    profile_photo_url TEXT,
    created_at TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS rooms (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    owner_uid TEXT,
    owner_name TEXT,
    knock_enabled INTEGER NOT NULL DEFAULT 1
  );

  CREATE TABLE IF NOT EXISTS knocks (
    id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL,
    room_name TEXT NOT NULL,
    requester_uid TEXT NOT NULL,
    requester_name TEXT NOT NULL,
    owner_uid TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TEXT NOT NULL,
    responded_at TEXT,
    requester_acknowledged INTEGER NOT NULL DEFAULT 0
  );

  CREATE TABLE IF NOT EXISTS todos (
    id TEXT PRIMARY KEY,
    uid TEXT NOT NULL,
    text TEXT NOT NULL,
    done INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    done_at TEXT
  );

  CREATE TABLE IF NOT EXISTS schedules (
    id TEXT PRIMARY KEY,
    uid TEXT NOT NULL,
    owner_name TEXT NOT NULL,
    date TEXT NOT NULL,
    title TEXT NOT NULL,
    memo TEXT,
    created_at TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS suggestions (
    id TEXT PRIMARY KEY,
    text TEXT NOT NULL,
    created_at TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS chats (
    id TEXT PRIMARY KEY,
    participants TEXT NOT NULL,
    participant_names TEXT NOT NULL,
    last_message TEXT,
    last_message_at TEXT,
    last_sender_uid TEXT,
    last_read_at TEXT NOT NULL DEFAULT '{}'
  );

  CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    chat_id TEXT NOT NULL,
    sender_uid TEXT NOT NULL,
    text TEXT NOT NULL,
    created_at TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS draws (
    id TEXT PRIMARY KEY,
    title TEXT,
    participant_uids TEXT NOT NULL,
    participant_names TEXT NOT NULL,
    winner_uid TEXT NOT NULL,
    winner_name TEXT NOT NULL,
    created_by_uid TEXT NOT NULL,
    created_at TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS sleep_sessions (
    id TEXT PRIMARY KEY,
    uid TEXT NOT NULL,
    slept_at TEXT NOT NULL,
    woke_at TEXT NOT NULL,
    duration_minutes INTEGER NOT NULL,
    created_at TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS alarms (
    id TEXT PRIMARY KEY,
    uid TEXT NOT NULL,
    label TEXT NOT NULL,
    hour INTEGER NOT NULL,
    minute INTEGER NOT NULL,
    repeat TEXT NOT NULL DEFAULT 'once',
    weekdays TEXT NOT NULL DEFAULT '[]',
    once_date TEXT,
    sound_id TEXT NOT NULL DEFAULT 'alarm_classic',
    custom_sound_path TEXT,
    enabled INTEGER NOT NULL DEFAULT 1
  );

  CREATE TABLE IF NOT EXISTS meta (
    key TEXT PRIMARY KEY,
    value TEXT
  );

  CREATE INDEX IF NOT EXISTS idx_knocks_owner ON knocks(owner_uid, status);
  CREATE INDEX IF NOT EXISTS idx_knocks_requester ON knocks(requester_uid);
  CREATE INDEX IF NOT EXISTS idx_todos_uid ON todos(uid);
  CREATE INDEX IF NOT EXISTS idx_schedules_uid_date ON schedules(uid, date);
  CREATE INDEX IF NOT EXISTS idx_messages_chat ON messages(chat_id, created_at);
  CREATE INDEX IF NOT EXISTS idx_sleep_uid ON sleep_sessions(uid);
  CREATE INDEX IF NOT EXISTS idx_alarms_uid ON alarms(uid);
`);
