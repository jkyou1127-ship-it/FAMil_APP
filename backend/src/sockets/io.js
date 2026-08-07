const db = require('../db');
const { publicUser } = require('../utils/serialize');

let ioInstance = null;

function setIo(io) {
  ioInstance = io;
}

function getIo() {
  return ioInstance;
}

function emitToUser(userId, event, payload) {
  if (!ioInstance) return;
  ioInstance.to(`user:${userId}`).emit(event, payload);
}

function broadcastStatus() {
  if (!ioInstance) return;
  const users = db.prepare('SELECT * FROM users ORDER BY id').all().map(publicUser);
  ioInstance.emit('status:update', { users });
}

function broadcastRooms() {
  if (!ioInstance) return;
  const { publicRoom } = require('../utils/serialize');
  const rooms = db.prepare('SELECT * FROM rooms ORDER BY id').all().map(publicRoom);
  ioInstance.emit('rooms:update', { rooms });
}

module.exports = { setIo, getIo, emitToUser, broadcastStatus, broadcastRooms };
