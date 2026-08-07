import { Server } from 'socket.io';
import { verifyToken } from './auth.js';

let io = null;

export function initSocket(httpServer) {
  io = new Server(httpServer, {
    cors: { origin: '*' },
  });

  io.use((socket, next) => {
    const token = socket.handshake.auth?.token;
    const payload = token ? verifyToken(token) : null;
    if (!payload) {
      return next(new Error('unauthorized'));
    }
    socket.uid = payload.uid;
    next();
  });

  io.on('connection', (socket) => {
    socket.join(`user:${socket.uid}`);
  });

  return io;
}

/** 인증된 모든 클라이언트에게 이벤트를 보낸다 (상태창/방/건의사항/추첨처럼 전체 공개 데이터). */
export function emitToAll(event, payload = {}) {
  io?.emit(event, payload);
}

/** 특정 사용자(들)에게만 이벤트를 보낸다. */
export function emitToUsers(uids, event, payload = {}) {
  for (const uid of new Set(uids)) {
    io?.to(`user:${uid}`).emit(event, payload);
  }
}
