const express = require('express');
const db = require('../db');
const { nowIso } = require('../utils/time');
const { authRequired } = require('../middleware/auth');
const { broadcast } = require('../sockets/io');

const router = express.Router();

function serialize(row) {
  return {
    id: row.id,
    content: row.content,
    bought: !!row.bought,
    addedBy: row.added_by,
    addedByName: row.added_by_name,
    boughtBy: row.bought_by,
    boughtByName: row.bought_by_name,
    createdAt: row.created_at,
    boughtAt: row.bought_at,
  };
}

function listItems() {
  const rows = db
    .prepare(
      `SELECT si.*, adder.display_name AS added_by_name, buyer.display_name AS bought_by_name
       FROM shopping_items si
       JOIN users adder ON adder.id = si.added_by
       LEFT JOIN users buyer ON buyer.id = si.bought_by
       ORDER BY si.bought ASC, si.created_at ASC`
    )
    .all();
  return rows.map(serialize);
}

function broadcastShoppingList() {
  broadcast('shopping:update', { items: listItems() });
}

// 온 가족이 함께 보고 채우는 장보기 목록. 개인 할 일과 달리 누구나 추가/체크할 수 있다.
router.get('/', authRequired, (req, res) => {
  res.json({ items: listItems() });
});

router.post('/', authRequired, (req, res) => {
  const { content } = req.body || {};
  const trimmed = content && String(content).trim();
  if (!trimmed) return res.status(400).json({ error: '살 것을 입력해주세요.' });

  db.prepare('INSERT INTO shopping_items (content, added_by, bought, created_at) VALUES (?, ?, 0, ?)').run(
    trimmed,
    req.user.id,
    nowIso()
  );
  broadcastShoppingList();
  res.status(201).json({ items: listItems() });
});

// 다 산 항목을 한 번에 정리한다 — '/:id'보다 먼저 선언해야 'bought'가 id로 잘못 매칭되지 않는다.
router.delete('/bought', authRequired, (req, res) => {
  db.prepare('DELETE FROM shopping_items WHERE bought = 1').run();
  broadcastShoppingList();
  res.status(204).end();
});

router.patch('/:id', authRequired, (req, res) => {
  const { id } = req.params;
  const row = db.prepare('SELECT * FROM shopping_items WHERE id = ?').get(id);
  if (!row) return res.status(404).json({ error: '항목을 찾을 수 없습니다.' });

  const { bought } = req.body || {};
  if (bought === true) {
    db.prepare('UPDATE shopping_items SET bought = 1, bought_by = ?, bought_at = ? WHERE id = ?').run(
      req.user.id,
      nowIso(),
      id
    );
  } else if (bought === false) {
    db.prepare('UPDATE shopping_items SET bought = 0, bought_by = NULL, bought_at = NULL WHERE id = ?').run(id);
  }
  broadcastShoppingList();
  res.json({ items: listItems() });
});

router.delete('/:id', authRequired, (req, res) => {
  const info = db.prepare('DELETE FROM shopping_items WHERE id = ?').run(req.params.id);
  if (info.changes === 0) return res.status(404).json({ error: '항목을 찾을 수 없습니다.' });
  broadcastShoppingList();
  res.status(204).end();
});

module.exports = router;
