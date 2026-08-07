import { Router } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db.js';
import { requireAuth } from '../auth.js';
import { serializeDraw } from '../serializers.js';
import { emitToAll } from '../socket.js';

export const drawsRouter = Router();
drawsRouter.use(requireAuth);

const listRecent = db.prepare('SELECT * FROM draws ORDER BY created_at DESC LIMIT 50');
const getDraw = db.prepare('SELECT * FROM draws WHERE id = ?');
const insertDraw = db.prepare(`
  INSERT INTO draws (id, title, participant_uids, participant_names, winner_uid, winner_name, created_by_uid, created_at)
  VALUES (@id, @title, @participantUids, @participantNames, @winnerUid, @winnerName, @createdByUid, @createdAt)
`);

drawsRouter.get('/', (req, res) => {
  res.json({ draws: listRecent.all().map(serializeDraw) });
});

// 참가자/당첨자는 클라이언트에서 정해서 보내고, 서버는 이력으로 저장만 한다
// (Flutter의 추첨 애니메이션이 클라이언트 로컬에서 실행되기 때문).
drawsRouter.post('/', (req, res) => {
  const { title, participantUids, participantNames, winnerUid, winnerName } = req.body || {};
  if (!Array.isArray(participantUids) || !winnerUid || !winnerName) {
    return res.status(400).json({ error: '참가자와 당첨자 정보가 필요합니다.' });
  }
  const id = uuidv4();
  insertDraw.run({
    id,
    title: title || null,
    participantUids: JSON.stringify(participantUids),
    participantNames: JSON.stringify(participantNames || []),
    winnerUid,
    winnerName,
    createdByUid: req.uid,
    createdAt: new Date().toISOString(),
  });
  emitToAll('draws:changed', {});
  res.status(201).json({ draw: serializeDraw(getDraw.get(id)) });
});
