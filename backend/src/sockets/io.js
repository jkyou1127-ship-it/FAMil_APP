// 다른 라우트 모듈(rooms.js, users.js, lottery.js 등)이 실시간 계층에 접근하는
// 창구. 내부 구현(ws_hub)이 바뀌어도 이 파일의 함수 시그니처만 유지하면 된다.
const hub = require('./ws_hub');

function emitToUser(userId, event, payload) {
  hub.emitToUser(userId, event, payload);
}

function broadcast(event, payload) {
  hub.broadcast(event, payload);
}

function broadcastStatus() {
  hub.broadcastStatus();
}

function broadcastRooms() {
  hub.broadcastRooms();
}

module.exports = { emitToUser, broadcast, broadcastStatus, broadcastRooms };
