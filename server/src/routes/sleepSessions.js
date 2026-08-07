import { Router } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db.js';
import { requireAuth } from '../auth.js';
import { serializeSleepSession } from '../serializers.js';
import { emitToUsers } from '../socket.js';

export const sleepSessionsRouter = Router();
sleepSessionsRouter.use(requireAuth);

const listMine = db.prepare(
  'SELECT * FROM sleep_sessions WHERE uid = ? ORDER BY woke_at DESC LIMIT 30'
);
const insertSession = db.prepare(`
  INSERT INTO sleep_sessions (id, uid, slept_at, woke_at, duration_minutes, created_at)
  VALUES (?, ?, ?, ?, ?, ?)
`);

sleepSessionsRouter.get('/', (req, res) => {
  res.json({ sessions: listMine.all(req.uid).map(serializeSleepSession) });
});

sleepSessionsRouter.post('/', (req, res) => {
  const { sleptAt, wokeAt } = req.body || {};
  if (!sleptAt || !wokeAt) {
    return res.status(400).json({ error: 'sleptAt, wokeAt은 필수입니다.' });
  }
  const durationMinutes = Math.round(
    (new Date(wokeAt).getTime() - new Date(sleptAt).getTime()) / 60000
  );
  const id = uuidv4();
  insertSession.run(id, req.uid, sleptAt, wokeAt, durationMinutes, new Date().toISOString());
  emitToUsers([req.uid], 'sleep:changed', {});
  res.status(201).json({ id });
});
