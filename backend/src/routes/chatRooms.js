const express = require('express');
const db = require('../db');
const { nowIso } = require('../utils/time');
const { authRequired } = require('../middleware/auth');
const { emitToUser } = require('../sockets/io');
const { sendPush } = require('../utils/push');

const router = express.Router();

function serializeRoom(row) {
  return { id: row.id, name: row.name, createdBy: row.created_by, createdAt: row.created_at };
}

function serializeMessage(row) {
  return {
    id: row.id,
    roomId: row.room_id,
    senderId: row.sender_id,
    senderName: row.sender_name,
    content: row.content,
    createdAt: row.created_at,
  };
}

function isMember(roomId, userId) {
  return !!db.prepare('SELECT 1 FROM chat_room_members WHERE room_id = ? AND user_id = ?').get(roomId, userId);
}

function memberIds(roomId) {
  return db.prepare('SELECT user_id FROM chat_room_members WHERE room_id = ?').all(roomId).map((r) => r.user_id);
}

// 내가 속한 단톡방 목록(마지막 메시지 + 안읽은 개수 + 멤버 목록 포함).
router.get('/', authRequired, (req, res) => {
  const rooms = db
    .prepare(
      `SELECT cr.*, crm.last_read_at
       FROM chat_rooms cr
       JOIN chat_room_members crm ON crm.room_id = cr.id
       WHERE crm.user_id = ?
       ORDER BY cr.created_at DESC`
    )
    .all(req.user.id);

  const result = rooms.map((room) => {
    const members = db
      .prepare(
        `SELECT u.id, u.display_name FROM chat_room_members crm
         JOIN users u ON u.id = crm.user_id WHERE crm.room_id = ?`
      )
      .all(room.id);
    const lastMessage = db
      .prepare('SELECT * FROM chat_room_messages WHERE room_id = ? ORDER BY created_at DESC LIMIT 1')
      .get(room.id);
    const unreadCount = db
      .prepare(
        `SELECT COUNT(*) AS c FROM chat_room_messages
         WHERE room_id = ? AND sender_id != ? AND (? IS NULL OR created_at > ?)`
      )
      .get(room.id, req.user.id, room.last_read_at, room.last_read_at).c;

    return {
      ...serializeRoom(room),
      members: members.map((m) => ({ id: m.id, displayName: m.display_name })),
      lastMessage: lastMessage
        ? serializeMessage({
            ...lastMessage,
            sender_name: db.prepare('SELECT display_name FROM users WHERE id = ?').get(lastMessage.sender_id)?.display_name,
          })
        : null,
      unreadCount,
    };
  });

  result.sort((a, b) => {
    const at = a.lastMessage ? a.lastMessage.createdAt : a.createdAt;
    const bt = b.lastMessage ? b.lastMessage.createdAt : b.createdAt;
    return at < bt ? 1 : at > bt ? -1 : 0;
  });

  res.json({ rooms: result });
});

// 단톡방 생성: 만든 사람도 자동으로 멤버가 된다.
router.post('/', authRequired, (req, res) => {
  const { name, memberIds: ids } = req.body || {};
  const trimmed = name && String(name).trim();
  if (!trimmed) return res.status(400).json({ error: '방 이름을 입력해주세요.' });
  if (!Array.isArray(ids) || ids.length === 0) {
    return res.status(400).json({ error: '초대할 사람을 한 명 이상 선택해주세요.' });
  }

  const createdAt = nowIso();
  const info = db
    .prepare('INSERT INTO chat_rooms (name, created_by, created_at) VALUES (?, ?, ?)')
    .run(trimmed, req.user.id, createdAt);
  const roomId = info.lastInsertRowid;

  const uniqueMemberIds = [...new Set([req.user.id, ...ids])];
  const insertMember = db.prepare(
    'INSERT INTO chat_room_members (room_id, user_id, joined_at) VALUES (?, ?, ?)'
  );
  for (const memberId of uniqueMemberIds) {
    const user = db.prepare('SELECT id FROM users WHERE id = ?').get(memberId);
    if (user) insertMember.run(roomId, memberId, createdAt);
  }

  const room = db.prepare('SELECT * FROM chat_rooms WHERE id = ?').get(roomId);
  for (const memberId of uniqueMemberIds) {
    if (memberId !== req.user.id) emitToUser(memberId, 'group:room:new', serializeRoom(room));
  }
  res.status(201).json({ room: serializeRoom(room) });
});

// 대화 내역 조회 (조회 시 읽음 처리).
router.get('/:id/messages', authRequired, (req, res) => {
  const roomId = req.params.id;
  if (!isMember(roomId, req.user.id)) return res.status(403).json({ error: '해당 단톡방의 멤버만 볼 수 있습니다.' });

  const rows = db
    .prepare(
      `SELECT crm.*, u.display_name AS sender_name FROM chat_room_messages crm
       JOIN users u ON u.id = crm.sender_id WHERE crm.room_id = ? ORDER BY crm.created_at ASC`
    )
    .all(roomId);

  db.prepare('UPDATE chat_room_members SET last_read_at = ? WHERE room_id = ? AND user_id = ?').run(
    nowIso(),
    roomId,
    req.user.id
  );

  res.json({ messages: rows.map(serializeMessage) });
});

// 소켓을 사용할 수 없는 환경을 위한 REST 발신 경로.
router.post('/:id/messages', authRequired, (req, res) => {
  const roomId = req.params.id;
  if (!isMember(roomId, req.user.id)) return res.status(403).json({ error: '해당 단톡방의 멤버만 보낼 수 있습니다.' });

  const { content } = req.body || {};
  const trimmed = content && String(content).trim();
  if (!trimmed) return res.status(400).json({ error: '메시지 내용을 입력해주세요.' });

  const createdAt = nowIso();
  const info = db
    .prepare('INSERT INTO chat_room_messages (room_id, sender_id, content, created_at) VALUES (?, ?, ?, ?)')
    .run(roomId, req.user.id, trimmed, createdAt);
  const message = serializeMessage({
    id: info.lastInsertRowid,
    room_id: Number(roomId),
    sender_id: req.user.id,
    sender_name: req.user.display_name,
    content: trimmed,
    created_at: createdAt,
  });

  const room = db.prepare('SELECT name FROM chat_rooms WHERE id = ?').get(roomId);
  for (const memberId of memberIds(roomId)) {
    emitToUser(memberId, 'group:message:new', message);
    if (memberId !== req.user.id) {
      sendPush(memberId, {
        title: `${req.user.display_name} (${room.name})`,
        body: trimmed,
        data: { type: 'group_message', roomId: String(roomId) },
      });
    }
  }
  res.status(201).json({ message });
});

// 멤버 추가: 기존 멤버 누구나 새 멤버를 초대할 수 있다.
router.post('/:id/members', authRequired, (req, res) => {
  const roomId = req.params.id;
  if (!isMember(roomId, req.user.id)) return res.status(403).json({ error: '해당 단톡방의 멤버만 초대할 수 있습니다.' });

  const { userId } = req.body || {};
  if (!userId) return res.status(400).json({ error: '초대할 사용자를 선택해주세요.' });
  const user = db.prepare('SELECT id, display_name FROM users WHERE id = ?').get(userId);
  if (!user) return res.status(404).json({ error: '사용자를 찾을 수 없습니다.' });
  if (isMember(roomId, userId)) return res.status(409).json({ error: '이미 참여 중인 사용자입니다.' });

  db.prepare('INSERT INTO chat_room_members (room_id, user_id, joined_at) VALUES (?, ?, ?)').run(
    roomId,
    userId,
    nowIso()
  );
  const room = db.prepare('SELECT * FROM chat_rooms WHERE id = ?').get(roomId);
  emitToUser(userId, 'group:room:new', serializeRoom(room));
  res.status(204).end();
});

// 단톡방 나가기.
router.delete('/:id/members/me', authRequired, (req, res) => {
  const roomId = req.params.id;
  const info = db
    .prepare('DELETE FROM chat_room_members WHERE room_id = ? AND user_id = ?')
    .run(roomId, req.user.id);
  if (info.changes === 0) return res.status(404).json({ error: '참여 중인 단톡방이 아닙니다.' });
  res.status(204).end();
});

module.exports = router;
