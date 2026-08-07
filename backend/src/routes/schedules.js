const express = require('express');
const db = require('../db');
const { nowIso } = require('../utils/time');
const { authRequired } = require('../middleware/auth');

const router = express.Router();

function serialize(row) {
  return { id: row.id, date: row.date, content: row.content, createdAt: row.created_at };
}

router.get('/', authRequired, (req, res) => {
  const { month } = req.query; // optional YYYY-MM filter
  let rows;
  if (month) {
    rows = db
      .prepare("SELECT * FROM schedules WHERE user_id = ? AND date LIKE ? ORDER BY date")
      .all(req.user.id, `${month}%`);
  } else {
    rows = db.prepare('SELECT * FROM schedules WHERE user_id = ? ORDER BY date').all(req.user.id);
  }
  res.json({ schedules: rows.map(serialize) });
});

router.post('/', authRequired, (req, res) => {
  const { date, content } = req.body || {};
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date || '')) {
    return res.status(400).json({ error: '날짜는 YYYY-MM-DD 형식이어야 합니다.' });
  }
  const trimmed = content && String(content).trim();
  if (!trimmed) return res.status(400).json({ error: '일정 내용을 입력해주세요.' });

  const createdAt = nowIso();
  const info = db
    .prepare('INSERT INTO schedules (user_id, date, content, created_at) VALUES (?, ?, ?, ?)')
    .run(req.user.id, date, trimmed, createdAt);
  const row = db.prepare('SELECT * FROM schedules WHERE id = ?').get(info.lastInsertRowid);
  res.status(201).json({ schedule: serialize(row) });
});

router.patch('/:id', authRequired, (req, res) => {
  const row = db.prepare('SELECT * FROM schedules WHERE id = ? AND user_id = ?').get(
    req.params.id,
    req.user.id
  );
  if (!row) return res.status(404).json({ error: '일정을 찾을 수 없습니다.' });

  const { date, content } = req.body || {};
  if (date !== undefined && !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return res.status(400).json({ error: '날짜는 YYYY-MM-DD 형식이어야 합니다.' });
  }
  db.prepare('UPDATE schedules SET date = ?, content = ? WHERE id = ?').run(
    date !== undefined ? date : row.date,
    content !== undefined ? String(content).trim() : row.content,
    row.id
  );
  const updated = db.prepare('SELECT * FROM schedules WHERE id = ?').get(row.id);
  res.json({ schedule: serialize(updated) });
});

router.delete('/:id', authRequired, (req, res) => {
  const info = db.prepare('DELETE FROM schedules WHERE id = ? AND user_id = ?').run(
    req.params.id,
    req.user.id
  );
  if (info.changes === 0) return res.status(404).json({ error: '일정을 찾을 수 없습니다.' });
  res.status(204).end();
});

module.exports = router;
