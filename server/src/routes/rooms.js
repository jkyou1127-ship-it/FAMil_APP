import { Router } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db.js';
import { requireAuth } from '../auth.js';
import { requireAdmin, isAdmin } from '../permissions.js';
import { serializeRoom } from '../serializers.js';
import { emitToAll } from '../socket.js';

export const roomsRouter = Router();
roomsRouter.use(requireAuth);

const listRooms = db.prepare('SELECT * FROM rooms ORDER BY name');
const getRoom = db.prepare('SELECT * FROM rooms WHERE id = ?');
const insertRoom = db.prepare('INSERT INTO rooms (id, name) VALUES (?, ?)');
const deleteRoom = db.prepare('DELETE FROM rooms WHERE id = ?');
const clearOwnerOnRooms = db.prepare(
  'UPDATE rooms SET owner_uid = NULL, owner_name = NULL WHERE owner_uid = ? AND id != ?'
);
const setRoomOwner = db.prepare(
  'UPDATE rooms SET owner_uid = ?, owner_name = ? WHERE id = ?'
);
const setUserRoom = db.prepare('UPDATE users SET room_id = ? WHERE id = ?');
const setKnockEnabled = db.prepare('UPDATE rooms SET knock_enabled = ? WHERE id = ?');
const getUserById = db.prepare('SELECT * FROM users WHERE id = ?');

roomsRouter.get('/', (req, res) => {
  res.json({ rooms: listRooms.all().map(serializeRoom) });
});

roomsRouter.post('/', requireAdmin, (req, res) => {
  const { name } = req.body || {};
  if (!name || !String(name).trim()) {
    return res.status(400).json({ error: '방 이름이 필요합니다.' });
  }
  const id = uuidv4();
  insertRoom.run(id, String(name).trim());
  emitToAll('rooms:changed', {});
  res.status(201).json({ room: serializeRoom(getRoom.get(id)) });
});

roomsRouter.delete('/:id', requireAdmin, (req, res) => {
  const room = getRoom.get(req.params.id);
  if (!room) return res.status(404).json({ error: 'not found' });
  if (room.owner_uid) setUserRoom.run(null, room.owner_uid);
  deleteRoom.run(req.params.id);
  emitToAll('rooms:changed', {});
  emitToAll('users:changed', {});
  res.json({ ok: true });
});

const assignOwnerTx = db.transaction((roomId, uid, displayName) => {
  clearOwnerOnRooms.run(uid, roomId);
  setRoomOwner.run(uid, displayName, roomId);
  setUserRoom.run(roomId, uid);
});

roomsRouter.post('/:id/assign-owner', requireAdmin, (req, res) => {
  const room = getRoom.get(req.params.id);
  if (!room) return res.status(404).json({ error: 'not found' });
  const user = getUserById.get(req.body?.uid);
  if (!user) return res.status(404).json({ error: '사용자를 찾을 수 없습니다.' });

  assignOwnerTx(room.id, user.id, user.display_name);
  emitToAll('rooms:changed', {});
  emitToAll('users:changed', {});
  res.json({ room: serializeRoom(getRoom.get(room.id)) });
});

roomsRouter.post('/:id/unassign-owner', requireAdmin, (req, res) => {
  const room = getRoom.get(req.params.id);
  if (!room) return res.status(404).json({ error: 'not found' });
  if (room.owner_uid) setUserRoom.run(null, room.owner_uid);
  setRoomOwner.run(null, null, room.id);
  emitToAll('rooms:changed', {});
  emitToAll('users:changed', {});
  res.json({ room: serializeRoom(getRoom.get(room.id)) });
});

// 출입 가능 여부(knockEnabled)는 관리자 또는 해당 방의 소유자만 바꿀 수 있다.
roomsRouter.patch('/:id', (req, res) => {
  const room = getRoom.get(req.params.id);
  if (!room) return res.status(404).json({ error: 'not found' });
  const isOwner = room.owner_uid === req.uid;
  const admin = isAdmin(req.uid);
  if (!isOwner && !admin) {
    return res.status(403).json({ error: '권한이 없습니다.' });
  }
  if (typeof req.body?.knockEnabled === 'boolean') {
    setKnockEnabled.run(req.body.knockEnabled ? 1 : 0, room.id);
  }
  emitToAll('rooms:changed', {});
  res.json({ room: serializeRoom(getRoom.get(room.id)) });
});
