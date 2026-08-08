const express = require('express');
const db = require('../db');
const { nowIso } = require('../utils/time');
const { publicRoom, publicUser } = require('../utils/serialize');
const { authRequired, adminRequired } = require('../middleware/auth');
const { emitToUser, broadcastRooms, broadcastStatus } = require('../sockets/io');
const { sendPush } = require('../utils/push');

const router = express.Router();

router.get('/', authRequired, (req, res) => {
  const rooms = db.prepare('SELECT * FROM rooms ORDER BY id').all().map(publicRoom);
  res.json({ rooms });
});

// 관리자가 새 방을 만든다.
router.post('/', authRequired, adminRequired, (req, res) => {
  const { name } = req.body || {};
  if (!name || !String(name).trim()) {
    return res.status(400).json({ error: '방 이름을 입력해주세요.' });
  }
  const createdAt = nowIso();
  const info = db
    .prepare('INSERT INTO rooms (name, access_status, created_at) VALUES (?, ?, ?)')
    .run(String(name).trim(), 'open', createdAt);
  const room = db.prepare('SELECT * FROM rooms WHERE id = ?').get(info.lastInsertRowid);
  broadcastRooms();
  res.status(201).json({ room: publicRoom(room) });
});

// 관리자가 방 이름을 변경한다.
router.patch('/:id/name', authRequired, adminRequired, (req, res) => {
  const room = db.prepare('SELECT * FROM rooms WHERE id = ?').get(req.params.id);
  if (!room) return res.status(404).json({ error: '방을 찾을 수 없습니다.' });

  const { name } = req.body || {};
  if (!name || !String(name).trim()) {
    return res.status(400).json({ error: '방 이름을 입력해주세요.' });
  }

  db.prepare('UPDATE rooms SET name = ? WHERE id = ?').run(String(name).trim(), room.id);
  const updatedRoom = db.prepare('SELECT * FROM rooms WHERE id = ?').get(room.id);
  broadcastRooms();
  res.json({ room: publicRoom(updatedRoom) });
});

// 관리자가 해당 방의 소유자(실제로 그 방에서 생활하는 사람)를 배정한다.
router.post('/:id/assign-owner', authRequired, adminRequired, (req, res) => {
  const room = db.prepare('SELECT * FROM rooms WHERE id = ?').get(req.params.id);
  if (!room) return res.status(404).json({ error: '방을 찾을 수 없습니다.' });

  const { userId } = req.body || {};
  if (!userId) return res.status(400).json({ error: '소유자로 지정할 사용자를 선택해주세요.' });
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
  if (!user) return res.status(404).json({ error: '사용자를 찾을 수 없습니다.' });

  const tx = db.transaction(() => {
    // 한 방에는 한 명의 소유자만 있을 수 있고, 한 사람은 한 방의 소유자만 될 수 있다.
    db.prepare('UPDATE rooms SET owner_id = NULL WHERE owner_id = ?').run(userId);
    db.prepare('UPDATE users SET room_id = NULL WHERE room_id = ? AND id != ?').run(room.id, userId);
    db.prepare('UPDATE rooms SET owner_id = ? WHERE id = ?').run(userId, room.id);
    db.prepare('UPDATE users SET room_id = ? WHERE id = ?').run(room.id, userId);
  });
  tx();

  const updatedRoom = db.prepare('SELECT * FROM rooms WHERE id = ?').get(room.id);
  broadcastRooms();
  broadcastStatus();
  res.json({ room: publicRoom(updatedRoom) });
});

// 방 소유자가 온라인 출입 가능/불가능 상태를 변경한다. (off 시 온라인 노크 시스템 비활성화)
router.patch('/:id/access', authRequired, (req, res) => {
  const room = db.prepare('SELECT * FROM rooms WHERE id = ?').get(req.params.id);
  if (!room) return res.status(404).json({ error: '방을 찾을 수 없습니다.' });
  if (room.owner_id !== req.user.id && !req.user.is_admin) {
    return res.status(403).json({ error: '해당 방의 소유자만 변경할 수 있습니다.' });
  }
  const { status } = req.body || {};
  if (!['open', 'closed'].includes(status)) {
    return res.status(400).json({ error: "status는 'open' 또는 'closed'여야 합니다." });
  }
  // 수동으로 바꾼 상태이므로, 취침 때문에 닫혔다는 표시는 지운다 — 그래야
  // 나중에 기상해도 방금 수동으로 정한 상태를 취침 기상이 덮어쓰지 않는다.
  db.prepare('UPDATE rooms SET access_status = ?, closed_by_sleep = 0 WHERE id = ?').run(status, room.id);
  const updatedRoom = db.prepare('SELECT * FROM rooms WHERE id = ?').get(room.id);
  broadcastRooms();
  res.json({ room: publicRoom(updatedRoom) });
});

// ---- 온라인 노크 ----

// 요청자가 들어갈 방을 클릭하면 소유자에게 알림이 간다.
router.post('/:id/knock', authRequired, (req, res) => {
  const room = db.prepare('SELECT * FROM rooms WHERE id = ?').get(req.params.id);
  if (!room) return res.status(404).json({ error: '방을 찾을 수 없습니다.' });
  if (!room.owner_id) return res.status(400).json({ error: '아직 소유자가 배정되지 않은 방입니다.' });
  if (room.owner_id === req.user.id) {
    return res.status(400).json({ error: '자신의 방에는 노크할 수 없습니다.' });
  }
  if (room.access_status !== 'open') {
    return res.status(403).json({ error: '현재 출입이 제한된 방입니다.' });
  }

  const createdAt = nowIso();
  const info = db
    .prepare(
      `INSERT INTO knocks (room_id, requester_id, status, created_at) VALUES (?, ?, 'pending', ?)`
    )
    .run(room.id, req.user.id, createdAt);

  const knock = {
    id: info.lastInsertRowid,
    roomId: room.id,
    roomName: room.name,
    requesterId: req.user.id,
    requesterName: req.user.display_name,
    status: 'pending',
    createdAt,
    respondedAt: null,
  };
  emitToUser(room.owner_id, 'knock:new', knock);
  sendPush(room.owner_id, {
    title: '온라인 노크',
    body: `${req.user.display_name}님이 "${room.name}" 방에 노크했습니다.`,
    data: { type: 'knock', knockId: knock.id },
  });
  res.status(201).json({ knock });
});

function serializeKnock(row) {
  return {
    id: row.id,
    roomId: row.room_id,
    roomName: row.room_name,
    requesterId: row.requester_id,
    requesterName: row.requester_name,
    status: row.status,
    createdAt: row.created_at,
    respondedAt: row.responded_at,
  };
}

// 내가 보낸 노크(요청자) 또는 내 방으로 들어온 노크(소유자) 목록을 조회한다.
router.get('/knocks/mine', authRequired, (req, res) => {
  const as = req.query.as === 'incoming' ? 'incoming' : 'outgoing';
  let rows;
  if (as === 'incoming') {
    rows = db
      .prepare(
        `SELECT k.*, r.name AS room_name, u.display_name AS requester_name
         FROM knocks k
         JOIN rooms r ON r.id = k.room_id
         JOIN users u ON u.id = k.requester_id
         WHERE r.owner_id = ?
         ORDER BY k.created_at DESC`
      )
      .all(req.user.id);
  } else {
    rows = db
      .prepare(
        `SELECT k.*, r.name AS room_name, u.display_name AS requester_name
         FROM knocks k
         JOIN rooms r ON r.id = k.room_id
         JOIN users u ON u.id = k.requester_id
         WHERE k.requester_id = ?
         ORDER BY k.created_at DESC`
      )
      .all(req.user.id);
  }
  res.json({ knocks: rows.map(serializeKnock) });
});

// 소유자가 노크를 승인/거절하면 요청자에게 알림이 간다.
router.post('/knocks/:knockId/respond', authRequired, (req, res) => {
  const row = db
    .prepare(
      `SELECT k.*, r.owner_id AS room_owner_id, r.name AS room_name, u.display_name AS requester_name
       FROM knocks k
       JOIN rooms r ON r.id = k.room_id
       JOIN users u ON u.id = k.requester_id
       WHERE k.id = ?`
    )
    .get(req.params.knockId);
  if (!row) return res.status(404).json({ error: '노크를 찾을 수 없습니다.' });
  if (row.room_owner_id !== req.user.id) {
    return res.status(403).json({ error: '해당 방의 소유자만 응답할 수 있습니다.' });
  }
  if (row.status !== 'pending') {
    return res.status(409).json({ error: '이미 처리된 노크입니다.' });
  }

  const { approve } = req.body || {};
  const status = approve ? 'approved' : 'denied';
  const respondedAt = nowIso();
  db.prepare('UPDATE knocks SET status = ?, responded_at = ? WHERE id = ?').run(
    status,
    respondedAt,
    row.id
  );

  const knock = serializeKnock({ ...row, status, responded_at: respondedAt });
  emitToUser(row.requester_id, 'knock:responded', knock);
  sendPush(row.requester_id, {
    title: '온라인 노크 응답',
    body: `"${row.room_name}" 방 노크가 ${approve ? '승인' : '거절'}되었습니다.`,
    data: { type: 'knock_responded', knockId: knock.id },
  });
  res.json({ knock });
});

module.exports = router;
