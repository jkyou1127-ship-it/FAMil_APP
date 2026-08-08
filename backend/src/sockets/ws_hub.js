const { WebSocketServer } = require('ws');
const jwt = require('jsonwebtoken');
const db = require('../db');

// userId -> Set<WebSocket>. A user can have multiple concurrent connections
// (phone + PC, or multiple tabs), so presence is tracked by set size, not a boolean.
const connections = new Map();
const eventHandlers = new Map();

/// 클라이언트가 보내는 이벤트(예: message:send)에 대한 핸들러를 등록한다.
/// Dart 서버의 RealtimeHub.on()과 동일한 역할 — 두 백엔드가 같은 프로토콜을 쓴다.
function on(event, handler) {
  eventHandlers.set(event, handler);
}

function emitToUser(userId, event, data) {
  const set = connections.get(userId);
  if (!set || set.size === 0) return;
  const payload = JSON.stringify({ event, data });
  for (const ws of set) {
    if (ws.readyState === ws.OPEN) ws.send(payload);
  }
}

function broadcast(event, data) {
  const payload = JSON.stringify({ event, data });
  for (const set of connections.values()) {
    for (const ws of set) {
      if (ws.readyState === ws.OPEN) ws.send(payload);
    }
  }
}

function broadcastStatus() {
  const { publicUser } = require('../utils/serialize');
  const users = db.prepare('SELECT * FROM users ORDER BY id').all().map(publicUser);
  broadcast('status:update', { users });
}

function broadcastRooms() {
  const { publicRoom } = require('../utils/serialize');
  const rooms = db.prepare('SELECT * FROM rooms ORDER BY id').all().map(publicRoom);
  broadcast('rooms:update', { rooms });
}

function handleConnection(userId, ws) {
  if (!connections.has(userId)) connections.set(userId, new Set());
  connections.get(userId).add(ws);
  db.prepare('UPDATE users SET online = 1 WHERE id = ?').run(userId);
  broadcastStatus();

  ws.on('message', (raw) => {
    let message;
    try {
      message = JSON.parse(raw.toString());
    } catch (err) {
      return;
    }
    const { event, data, ackId } = message || {};
    if (typeof event !== 'string') return;
    const handler = eventHandlers.get(event);
    if (!handler) return;
    handler(userId, data || {}, (ackData) => {
      if (ackId == null) return;
      if (ws.readyState === ws.OPEN) ws.send(JSON.stringify({ event: 'ack', ackId, data: ackData }));
    });
  });

  const handleDisconnect = () => {
    const set = connections.get(userId);
    if (!set) return;
    set.delete(ws);
    if (set.size === 0) {
      connections.delete(userId);
      db.prepare('UPDATE users SET online = 0 WHERE id = ?').run(userId);
      broadcastStatus();
    }
  };
  ws.on('close', handleDisconnect);
  ws.on('error', handleDisconnect);
}

/// `/realtime?token=<jwt>`로 들어오는 업그레이드 요청을 처리한다. 업그레이드가
/// 완료되기 전에 토큰을 검증해, 인증되지 않은 연결은 핸드셰이크 자체를 거부한다
/// (Dart 서버의 buildRealtimeHandler와 동일한 인증 방식 — 둘 다 쿼리 파라미터 토큰).
function attachWebSocketServer(server) {
  const wss = new WebSocketServer({ noServer: true });

  server.on('upgrade', (request, socket, head) => {
    let url;
    try {
      url = new URL(request.url, `http://${request.headers.host}`);
    } catch (err) {
      socket.destroy();
      return;
    }
    if (url.pathname !== '/realtime') {
      socket.destroy();
      return;
    }

    const token = url.searchParams.get('token');
    if (!token) {
      socket.write('HTTP/1.1 403 Forbidden\r\n\r\n');
      socket.destroy();
      return;
    }

    let payload;
    try {
      payload = jwt.verify(token, process.env.JWT_SECRET);
    } catch (err) {
      socket.write('HTTP/1.1 403 Forbidden\r\n\r\n');
      socket.destroy();
      return;
    }

    const user = db.prepare('SELECT id FROM users WHERE id = ?').get(payload.id);
    if (!user) {
      socket.write('HTTP/1.1 403 Forbidden\r\n\r\n');
      socket.destroy();
      return;
    }

    wss.handleUpgrade(request, socket, head, (ws) => {
      handleConnection(user.id, ws);
    });
  });

  return wss;
}

module.exports = { on, emitToUser, broadcast, broadcastStatus, broadcastRooms, attachWebSocketServer };
