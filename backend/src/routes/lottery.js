const express = require('express');
const db = require('../db');
const { nowIso } = require('../utils/time');
const { authRequired } = require('../middleware/auth');
const { broadcast } = require('../sockets/io');

const router = express.Router();

// 현재 온라인인 인원 중에서 추첨한다.
router.post('/draw', authRequired, (req, res) => {
  const online = db.prepare('SELECT id, display_name FROM users WHERE online = 1').all();
  if (online.length === 0) {
    return res.status(400).json({ error: '현재 온라인인 사용자가 없습니다.' });
  }

  const winner = online[Math.floor(Math.random() * online.length)];
  const createdAt = nowIso();
  const participantIds = online.map((u) => u.id);
  db.prepare(
    `INSERT INTO lottery_draws (winner_id, participant_ids, drawn_by, created_at)
     VALUES (?, ?, ?, ?)`
  ).run(winner.id, JSON.stringify(participantIds), req.user.id, createdAt);

  const result = {
    winnerId: winner.id,
    winnerName: winner.display_name,
    participantIds,
    drawnBy: req.user.id,
    createdAt,
  };

  broadcast('lottery:drawn', result);
  res.status(201).json({ result });
});

router.get('/history', authRequired, (req, res) => {
  const rows = db
    .prepare(
      `SELECT ld.*, u.display_name AS winner_name
       FROM lottery_draws ld JOIN users u ON u.id = ld.winner_id
       ORDER BY ld.created_at DESC LIMIT 50`
    )
    .all();
  res.json({
    history: rows.map((r) => ({
      id: r.id,
      winnerId: r.winner_id,
      winnerName: r.winner_name,
      participantIds: JSON.parse(r.participant_ids),
      drawnBy: r.drawn_by,
      createdAt: r.created_at,
    })),
  });
});

module.exports = router;
