const jwt = require('jsonwebtoken');
const db = require('../db');
const { nowIso } = require('../utils/time');
const { setIo, broadcastStatus } = require('./io');

// userId -> number of concurrently connected sockets (tracked in-process,
// independent of socket.io's own room bookkeeping so presence stays correct
// even if a user has multiple devices/tabs open).
const onlineCounts = new Map();

function initSockets(io) {
  setIo(io);

  io.use((socket, next) => {
    const token = socket.handshake.auth && socket.handshake.auth.token;
    if (!token) return next(new Error('unauthorized'));
    try {
      const payload = jwt.verify(token, process.env.JWT_SECRET);
      const user = db.prepare('SELECT id FROM users WHERE id = ?').get(payload.id);
      if (!user) return next(new Error('unauthorized'));
      socket.userId = user.id;
      next();
    } catch (err) {
      next(new Error('unauthorized'));
    }
  });

  io.on('connection', (socket) => {
    const userId = socket.userId;
    socket.join(`user:${userId}`);

    onlineCounts.set(userId, (onlineCounts.get(userId) || 0) + 1);
    db.prepare('UPDATE users SET online = 1 WHERE id = ?').run(userId);
    broadcastStatus();

    socket.on('message:send', (payload, ack) => {
      const receiverId = payload && payload.receiverId;
      const content = payload && String(payload.content || '').trim();
      if (!receiverId || !content) {
        if (typeof ack === 'function') ack({ error: '메시지 내용을 입력해주세요.' });
        return;
      }
      const receiver = db.prepare('SELECT id FROM users WHERE id = ?').get(receiverId);
      if (!receiver) {
        if (typeof ack === 'function') ack({ error: '상대방을 찾을 수 없습니다.' });
        return;
      }
      const createdAt = nowIso();
      const info = db
        .prepare(
          `INSERT INTO messages (sender_id, receiver_id, content, created_at) VALUES (?, ?, ?, ?)`
        )
        .run(userId, receiverId, content, createdAt);
      const message = {
        id: info.lastInsertRowid,
        senderId: userId,
        receiverId,
        content,
        createdAt,
        readAt: null,
      };
      io.to(`user:${receiverId}`).emit('message:new', message);
      io.to(`user:${userId}`).emit('message:new', message);
      if (typeof ack === 'function') ack({ message });
    });

    socket.on('disconnect', () => {
      const remaining = (onlineCounts.get(userId) || 1) - 1;
      if (remaining <= 0) {
        onlineCounts.delete(userId);
        db.prepare('UPDATE users SET online = 0 WHERE id = ?').run(userId);
        broadcastStatus();
      } else {
        onlineCounts.set(userId, remaining);
      }
    });
  });
}

module.exports = { initSockets };
