const express = require('express');
const db = require('../db');
const { nowIso } = require('../utils/time');
const { authRequired } = require('../middleware/auth');

const router = express.Router();

// 건의사항은 "익명"으로 등록되며 작성자 정보는 저장하지 않는다.
router.post('/', authRequired, (req, res) => {
  const { content } = req.body || {};
  const trimmed = content && String(content).trim();
  if (!trimmed) return res.status(400).json({ error: '건의 내용을 입력해주세요.' });

  const createdAt = nowIso();
  const info = db
    .prepare('INSERT INTO suggestions (content, created_at) VALUES (?, ?)')
    .run(trimmed, createdAt);
  res.status(201).json({ suggestion: { id: info.lastInsertRowid, content: trimmed, createdAt } });
});

// 건의사항은 "모두"가 확인할 수 있다.
router.get('/', authRequired, (req, res) => {
  const rows = db.prepare('SELECT * FROM suggestions ORDER BY created_at DESC').all();
  res.json({
    suggestions: rows.map((r) => ({ id: r.id, content: r.content, createdAt: r.created_at })),
  });
});

module.exports = router;
