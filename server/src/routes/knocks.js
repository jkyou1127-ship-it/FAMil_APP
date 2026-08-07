import { Router } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db.js';
import { requireAuth } from '../auth.js';
import { serializeKnock } from '../serializers.js';
import { emitToUsers } from '../socket.js';

export const knocksRouter = Router();
knocksRouter.use(requireAuth);

const getRoom = db.prepare('SELECT * FROM rooms WHERE id = ?');
const getUserById = db.prepare('SELECT * FROM users WHERE id = ?');
const insertKnock = db.prepare(`
  INSERT INTO knocks (id, room_id, room_name, requester_uid, requester_name, owner_uid, status, created_at)
  VALUES (@id, @roomId, @roomName, @requesterUid, @requesterName, @ownerUid, 'pending', @createdAt)
`);
const getKnock = db.prepare('SELECT * FROM knocks WHERE id = ?');
const listIncoming = db.prepare(
  "SELECT * FROM knocks WHERE owner_uid = ? AND status = 'pending' ORDER BY created_at DESC"
);
const listResponses = db.prepare(
  "SELECT * FROM knocks WHERE requester_uid = ? AND status != 'pending' AND requester_acknowledged = 0"
);
const respondStmt = db.prepare(
  'UPDATE knocks SET status = ?, responded_at = ? WHERE id = ?'
);
const acknowledgeStmt = db.prepare(
  'UPDATE knocks SET requester_acknowledged = 1 WHERE id = ?'
);

knocksRouter.post('/', (req, res) => {
  const room = getRoom.get(req.body?.roomId);
  if (!room) return res.status(404).json({ error: '방을 찾을 수 없습니다.' });
  if (!room.owner_uid) return res.status(400).json({ error: '소유자가 없는 방입니다.' });
  if (!room.knock_enabled) return res.status(400).json({ error: '현재 출입이 불가능합니다.' });
  if (room.owner_uid === req.uid) return res.status(400).json({ error: '본인 방은 노크할 수 없습니다.' });

  const me = getUserById.get(req.uid);
  const id = uuidv4();
  insertKnock.run({
    id,
    roomId: room.id,
    roomName: room.name,
    requesterUid: req.uid,
    requesterName: me.display_name,
    ownerUid: room.owner_uid,
    createdAt: new Date().toISOString(),
  });
  emitToUsers([room.owner_uid], 'knocks:changed', {});
  res.status(201).json({ knock: serializeKnock(getKnock.get(id)) });
});

knocksRouter.get('/incoming', (req, res) => {
  res.json({ knocks: listIncoming.all(req.uid).map(serializeKnock) });
});

knocksRouter.get('/responses', (req, res) => {
  res.json({ knocks: listResponses.all(req.uid).map(serializeKnock) });
});

knocksRouter.patch('/:id/respond', (req, res) => {
  const knock = getKnock.get(req.params.id);
  if (!knock) return res.status(404).json({ error: 'not found' });
  if (knock.owner_uid !== req.uid) return res.status(403).json({ error: '권한이 없습니다.' });
  const approve = !!req.body?.approve;
  respondStmt.run(approve ? 'approved' : 'denied', new Date().toISOString(), knock.id);
  emitToUsers([knock.requester_uid], 'knocks:changed', {});
  res.json({ knock: serializeKnock(getKnock.get(knock.id)) });
});

knocksRouter.patch('/:id/acknowledge', (req, res) => {
  const knock = getKnock.get(req.params.id);
  if (!knock) return res.status(404).json({ error: 'not found' });
  if (knock.requester_uid !== req.uid) return res.status(403).json({ error: '권한이 없습니다.' });
  acknowledgeStmt.run(knock.id);
  res.json({ ok: true });
});
