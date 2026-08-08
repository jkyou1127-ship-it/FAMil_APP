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
}

module.exports = { initSockets };
