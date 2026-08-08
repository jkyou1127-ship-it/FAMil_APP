const db = require('../db');
const { nowIso } = require('../utils/time');
const { sendPush } = require('../utils/push');
const hub = require('./ws_hub');

/// Socket.IO를 raw WebSocket + JSON 이벤트 봉투({event, data[, ackId]})로 대체한
/// 실시간 계층. Dart로 유지보수 가능한 Socket.IO 서버 구현체가 없어서, 두
/// 백엔드(Node/Dart)가 같은 프로토콜을 쓰도록 이쪽도 동일하게 맞췄다.
function initSockets(server) {
  hub.attachWebSocketServer(server);

  hub.on('message:send', (userId, data, ack) => {
    const receiverId = data && data.receiverId;
    const content = data && String(data.content || '').trim();
    if (!receiverId || !content) {
      ack({ error: '메시지 내용을 입력해주세요.' });
      return;
    }
    const receiver = db.prepare('SELECT id FROM users WHERE id = ?').get(receiverId);
    if (!receiver) {
      ack({ error: '상대방을 찾을 수 없습니다.' });
      return;
    }

    const createdAt = nowIso();
    const info = db
      .prepare('INSERT INTO messages (sender_id, receiver_id, content, created_at) VALUES (?, ?, ?, ?)')
      .run(userId, receiverId, content, createdAt);
    const message = {
      id: info.lastInsertRowid,
      senderId: userId,
      receiverId,
      content,
      createdAt,
      readAt: null,
    };
    hub.emitToUser(receiverId, 'message:new', message);
    hub.emitToUser(userId, 'message:new', message);
    ack({ message });

    const sender = db.prepare('SELECT display_name FROM users WHERE id = ?').get(userId);
    sendPush(receiverId, {
      title: sender ? sender.display_name : '새 메시지',
      body: content,
      data: { type: 'message', senderId: userId },
    });
  });

  hub.on('group:message:send', (userId, data, ack) => {
    const roomId = data && data.roomId;
    const content = data && String(data.content || '').trim();
    if (!roomId || !content) {
      ack({ error: '메시지 내용을 입력해주세요.' });
      return;
    }
    const isMember = db
      .prepare('SELECT 1 FROM chat_room_members WHERE room_id = ? AND user_id = ?')
      .get(roomId, userId);
    if (!isMember) {
      ack({ error: '해당 단톡방의 멤버만 보낼 수 있습니다.' });
      return;
    }

    const createdAt = nowIso();
    const info = db
      .prepare('INSERT INTO chat_room_messages (room_id, sender_id, content, created_at) VALUES (?, ?, ?, ?)')
      .run(roomId, userId, content, createdAt);
    const sender = db.prepare('SELECT display_name FROM users WHERE id = ?').get(userId);
    const message = {
      id: info.lastInsertRowid,
      roomId: Number(roomId),
      senderId: userId,
      senderName: sender ? sender.display_name : null,
      content,
      createdAt,
    };

    const room = db.prepare('SELECT name FROM chat_rooms WHERE id = ?').get(roomId);
    const memberIds = db
      .prepare('SELECT user_id FROM chat_room_members WHERE room_id = ?')
      .all(roomId)
      .map((r) => r.user_id);
    for (const memberId of memberIds) {
      hub.emitToUser(memberId, 'group:message:new', message);
      if (memberId !== userId) {
        sendPush(memberId, {
          title: `${sender ? sender.display_name : ''} (${room ? room.name : ''})`,
          body: content,
          data: { type: 'group_message', roomId: String(roomId) },
        });
      }
    }
    ack({ message });
  });
}

module.exports = { initSockets };
