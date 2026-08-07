const express = require('express');
const db = require('../db');
const { nowIso, kstDateString } = require('../utils/time');
const { authRequired } = require('../middleware/auth');

const router = express.Router();

function serialize(row) {
  return {
    id: row.id,
    content: row.content,
    completed: !!row.completed,
    completedDate: row.completed_date,
    createdAt: row.created_at,
  };
}

router.get('/', authRequired, (req, res) => {
  const rows = db
    .prepare('SELECT * FROM todos WHERE user_id = ? ORDER BY completed, created_at DESC')
    .all(req.user.id);
  res.json({ todos: rows.map(serialize) });
});

router.post('/', authRequired, (req, res) => {
  const { content } = req.body || {};
  const trimmed = content && String(content).trim();
  if (!trimmed) return res.status(400).json({ error: '할 일 내용을 입력해주세요.' });

  const createdAt = nowIso();
  const info = db
    .prepare('INSERT INTO todos (user_id, content, created_at) VALUES (?, ?, ?)')
    .run(req.user.id, trimmed, createdAt);
  const row = db.prepare('SELECT * FROM todos WHERE id = ?').get(info.lastInsertRowid);
  res.status(201).json({ todo: serialize(row) });
});

// 완료 시 취소선 + 회색 처리(클라이언트), 완료된 날짜를 기록해 자정 정리 작업이 사용한다.
router.patch('/:id', authRequired, (req, res) => {
  const row = db.prepare('SELECT * FROM todos WHERE id = ? AND user_id = ?').get(
    req.params.id,
    req.user.id
  );
  if (!row) return res.status(404).json({ error: '할 일을 찾을 수 없습니다.' });

  const { content, completed } = req.body || {};
  const nextCompleted = completed !== undefined ? !!completed : !!row.completed;
  const completedDate = nextCompleted
    ? row.completed_date || kstDateString()
    : null;

  db.prepare('UPDATE todos SET content = ?, completed = ?, completed_date = ? WHERE id = ?').run(
    content !== undefined ? String(content).trim() : row.content,
    nextCompleted ? 1 : 0,
    completedDate,
    row.id
  );
  const updated = db.prepare('SELECT * FROM todos WHERE id = ?').get(row.id);
  res.json({ todo: serialize(updated) });
});

router.delete('/:id', authRequired, (req, res) => {
  const info = db.prepare('DELETE FROM todos WHERE id = ? AND user_id = ?').run(
    req.params.id,
    req.user.id
  );
  if (info.changes === 0) return res.status(404).json({ error: '할 일을 찾을 수 없습니다.' });
  res.status(204).end();
});

module.exports = router;
