import { Router } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db.js';
import { requireAuth } from '../auth.js';
import { serializeSchedule } from '../serializers.js';
import { emitToAll } from '../socket.js';

export const schedulesRouter = Router();
schedulesRouter.use(requireAuth);

const listByUid = db.prepare('SELECT * FROM schedules WHERE uid = ? ORDER BY date');
const listByUidAndDate = db.prepare('SELECT * FROM schedules WHERE uid = ? AND date = ?');
const getSchedule = db.prepare('SELECT * FROM schedules WHERE id = ?');
const insertSchedule = db.prepare(`
  INSERT INTO schedules (id, uid, owner_name, date, title, memo, created_at)
  VALUES (@id, @uid, @ownerName, @date, @title, @memo, @createdAt)
`);
const deleteSchedule = db.prepare('DELETE FROM schedules WHERE id = ?');
const getUserById = db.prepare('SELECT * FROM users WHERE id = ?');

// ?uid=&date= 조합에 따라 특정 사용자의 전체 일정 또는 특정 날짜 일정을 조회한다.
// (상태창에서 다른 사용자의 오늘 일정을 보여주기 위해 누구나 조회 가능)
schedulesRouter.get('/', (req, res) => {
  const uid = req.query.uid || req.uid;
  const date = req.query.date;
  const rows = date ? listByUidAndDate.all(uid, date) : listByUid.all(uid);
  res.json({ schedules: rows.map(serializeSchedule) });
});

schedulesRouter.post('/', (req, res) => {
  const { date, title, memo } = req.body || {};
  if (!date || !title) return res.status(400).json({ error: 'date, title은 필수입니다.' });
  const me = getUserById.get(req.uid);
  const id = uuidv4();
  insertSchedule.run({
    id,
    uid: req.uid,
    ownerName: me.display_name,
    date,
    title,
    memo: memo || null,
    createdAt: new Date().toISOString(),
  });
  emitToAll('schedules:changed', {});
  res.status(201).json({ schedule: serializeSchedule(getSchedule.get(id)) });
});

schedulesRouter.delete('/:id', (req, res) => {
  const row = getSchedule.get(req.params.id);
  if (!row || row.uid !== req.uid) return res.status(404).json({ error: 'not found' });
  deleteSchedule.run(row.id);
  emitToAll('schedules:changed', {});
  res.json({ ok: true });
});
