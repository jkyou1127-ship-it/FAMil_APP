import { Router } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db.js';
import { requireAuth } from '../auth.js';
import { serializeChat, serializeMessage } from '../serializers.js';
import { emitToUsers } from '../socket.js';

export const chatsRouter = Router();
chatsRouter.use(requireAuth);

const listAllChats = db.prepare('SELECT * FROM chats');
const getChat = db.prepare('SELECT * FROM chats WHERE id = ?');
const upsertChat = db.prepare(`
  INSERT INTO chats (id, participants, participant_names, last_message, last_message_at, last_sender_uid, last_read_at)
  VALUES (@id, @participants, @participantNames, @lastMessage, @lastMessageAt, @lastSenderUid, '{}')
  ON CONFLICT(id) DO UPDATE SET
    last_message = @lastMessage,
    last_message_at = @lastMessageAt,
    last_sender_uid = @lastSenderUid
`);
const setLastRead = db.prepare('UPDATE chats SET last_read_at = ? WHERE id = ?');
const insertMessage = db.prepare(
  'INSERT INTO messages (id, chat_id, sender_uid, text, created_at) VALUES (?, ?, ?, ?, ?)'
);
const listMessages = db.prepare(
  'SELECT * FROM messages WHERE chat_id = ? ORDER BY created_at DESC LIMIT 200'
);
const getUserById = db.prepare('SELECT * FROM users WHERE id = ?');

function chatIdFor(a, b) {
  return [a, b].sort().join('_');
}

chatsRouter.get('/mine', (req, res) => {
  const mine = listAllChats
    .all()
    .filter((row) => JSON.parse(row.participants).includes(req.uid))
    .sort((a, b) => (b.last_message_at || '').localeCompare(a.last_message_at || ''));
  res.json({ chats: mine.map(serializeChat) });
});

chatsRouter.get('/:chatId/messages', (req, res) => {
  const chat = getChat.get(req.params.chatId);
  if (!chat || !JSON.parse(chat.participants).includes(req.uid)) {
    return res.status(404).json({ error: 'not found' });
  }
  res.json({ messages: listMessages.all(chat.id).map(serializeMessage) });
});

chatsRouter.post('/:otherUid/messages', (req, res) => {
  const text = (req.body?.text || '').trim();
  if (!text) return res.status(400).json({ error: '내용을 입력하세요.' });
  const other = getUserById.get(req.params.otherUid);
  if (!other) return res.status(404).json({ error: '상대를 찾을 수 없습니다.' });
  const me = getUserById.get(req.uid);

  const chatId = chatIdFor(req.uid, other.id);
  const now = new Date().toISOString();
  upsertChat.run({
    id: chatId,
    participants: JSON.stringify([req.uid, other.id]),
    participantNames: JSON.stringify({ [req.uid]: me.display_name, [other.id]: other.display_name }),
    lastMessage: text,
    lastMessageAt: now,
    lastSenderUid: req.uid,
  });
  const msgId = uuidv4();
  insertMessage.run(msgId, chatId, req.uid, text, now);

  emitToUsers([req.uid, other.id], 'chats:changed', { chatId });
  res.status(201).json({ chatId });
});

chatsRouter.post('/:chatId/read', (req, res) => {
  const chat = getChat.get(req.params.chatId);
  if (!chat || !JSON.parse(chat.participants).includes(req.uid)) {
    return res.status(404).json({ error: 'not found' });
  }
  const lastReadAt = JSON.parse(chat.last_read_at || '{}');
  lastReadAt[req.uid] = new Date().toISOString();
  setLastRead.run(JSON.stringify(lastReadAt), chat.id);
  res.json({ ok: true });
});
