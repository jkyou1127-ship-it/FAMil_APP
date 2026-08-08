const { WebSocketServer } = require('ws');
const jwt = require('jsonwebtoken');
const db = require('../db');

// userId -> Set<WebSocket>. A user can have multiple concurrent connections
// (phone + PC, or multiple tabs), so presence is tracked by set size, not a boolean.
const connections = new Map();
const eventHandlers = new Map();

// 끊긴 즉시 오프라인 처리하면, 잠깐의 네트워크 끊김 후 재연결되는 정상적인
// 경우에도 "온라인인데 오프라인으로 보임" 깜빡임이 생긴다. 유예 시간을 두고,
// 그 안에 재연결되면 오프라인 처리를 취소한다.
const OFFLINE_GRACE_MS = 8000;
const offlineTimers = new Map(); // userId -> Timeout

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

function markOnline(userId) {
  const pendingOffline = offlineTimers.get(userId);
  if (pendingOffline) {
    clearTimeout(pendingOffline);
    offlineTimers.delete(userId);
  }
  db.prepare('UPDATE users SET online = 1 WHERE id = ?').run(userId);
  broadcastStatus();
}

function scheduleOffline(userId) {
  if (offlineTimers.has(userId)) return;
  const timer = setTimeout(() => {
    offlineTimers.delete(userId);
    const set = connections.get(userId);
    if (set && set.size > 0) return; // 유예 시간 안에 재연결됨
    db.prepare('UPDATE users SET online = 0 WHERE id = ?').run(userId);
    broadcastStatus();
  }, OFFLINE_GRACE_MS);
  offlineTimers.set(userId, timer);
}

function handleConnection(userId, ws) {
  if (!connections.has(userId)) connections.set(userId, new Set());
  connections.get(userId).add(ws);
  markOnline(userId);

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
      scheduleOffline(userId);
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
