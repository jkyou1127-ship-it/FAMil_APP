const express = require('express');
const db = require('../db');
const { nowIso } = require('../utils/time');
const { authRequired } = require('../middleware/auth');
const { emitToUser } = require('../sockets/io');

const router = express.Router();

function serializeMessage(row) {
  return {
    id: row.id,
    senderId: row.sender_id,
    receiverId: row.receiver_id,
    content: row.content,
    createdAt: row.created_at,
    readAt: row.read_at,
  };
}

// 대화 상대 목록(마지막 메시지 + 안읽은 개수)
router.get('/conversations', authRequired, (req, res) => {
  const meId = req.user.id;
  const partners = db
    .prepare(
      `SELECT DISTINCT CASE WHEN sender_id = ? THEN receiver_id ELSE sender_id END AS partner_id
       FROM messages WHERE sender_id = ? OR receiver_id = ?`
    )
    .all(meId, meId, meId)
    .map((r) => r.partner_id);

  const conversations = partners.map((partnerId) => {
    const partner = db.prepare('SELECT id, display_name, profile_photo, online FROM users WHERE id = ?').get(partnerId);
    const lastMessage = db
      .prepare(
        `SELECT * FROM messages
         WHERE (sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)
         ORDER BY created_at DESC LIMIT 1`
      )
      .get(meId, partnerId, partnerId, meId);
    const unreadCount = db
      .prepare(
        `SELECT COUNT(*) AS c FROM messages WHERE sender_id = ? AND receiver_id = ? AND read_at IS NULL`
      )
      .get(partnerId, meId).c;
    return {
      partner: partner && {
        id: partner.id,
        displayName: partner.display_name,
        profilePhoto: partner.profile_photo,
        online: !!partner.online,
      },
      lastMessage: lastMessage ? serializeMessage(lastMessage) : null,
      unreadCount,
    };
  });

  conversations.sort((a, b) => {
    const at = a.lastMessage ? a.lastMessage.createdAt : '';
    const bt = b.lastMessage ? b.lastMessage.createdAt : '';
    return at < bt ? 1 : at > bt ? -1 : 0;
  });

  res.json({ conversations });
});

// 특정 상대와의 대화 내역 (조회 시 상대가 보낸 메시지를 읽음 처리)
router.get('/:userId', authRequired, (req, res) => {
  const meId = req.user.id;
  const partnerId = Number(req.params.userId);

  const rows = db
    .prepare(
      `SELECT * FROM messages
       WHERE (sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)
       ORDER BY created_at ASC`
    )
    .all(meId, partnerId, partnerId, meId);

  const readAt = nowIso();
  db.prepare(
    `UPDATE messages SET read_at = ? WHERE sender_id = ? AND receiver_id = ? AND read_at IS NULL`
  ).run(readAt, partnerId, meId);

  res.json({ messages: rows.map(serializeMessage) });
});

// 소켓을 사용할 수 없는 환경을 위한 REST 발신 경로 (소켓과 동일하게 동작)
router.post('/', authRequired, (req, res) => {
  const { receiverId, content } = req.body || {};
  const trimmed = content && String(content).trim();
  if (!receiverId || !trimmed) {
    return res.status(400).json({ error: '받는 사람과 내용을 입력해주세요.' });
  }
  const receiver = db.prepare('SELECT id FROM users WHERE id = ?').get(receiverId);
  if (!receiver) return res.status(404).json({ error: '상대방을 찾을 수 없습니다.' });

  const createdAt = nowIso();
  const info = db
    .prepare('INSERT INTO messages (sender_id, receiver_id, content, created_at) VALUES (?, ?, ?, ?)')
    .run(req.user.id, receiverId, trimmed, createdAt);
  const message = serializeMessage({
    id: info.lastInsertRowid,
    sender_id: req.user.id,
    receiver_id: receiverId,
    content: trimmed,
    created_at: createdAt,
    read_at: null,
  });
  emitToUser(receiverId, 'message:new', message);
  emitToUser(req.user.id, 'message:new', message);
  res.status(201).json({ message });
});

module.exports = router;
