const express = require('express');
const fs = require('fs');
const os = require('os');
const path = require('path');
const db = require('../db');
const { authRequired } = require('../middleware/auth');

const router = express.Router();
// 관리자만이 아니라, 로그인한 가족 구성원 누구나 PC가 꺼졌을 때 자기 폰을
// 임시 백업 서버로 켤 수 있어야 한다 — 꼭 관리자가 그 자리에 있으리라는
// 보장이 없기 때문이다.
router.use(authRequired);

// PC가 꺼졌을 때 폰이 "임시 백업 서버" 역할을 할 수 있도록, 현재 DB의 스냅샷을
// 내려받기 전에 병합 시점 계산에 필요한 기준값(각 테이블의 현재 최대 id, 시각)을
// 알려준다. 백업 중 새로 생긴 행(새 사용자/새 방/새 단톡방)은 기준 이후 id를 갖게
// 되므로, 나중에 병합할 때 "출입 전부터 있던 대상"인지 걸러내는 데 쓰인다.
router.get('/meta', (req, res) => {
  const maxId = (table) => db.prepare(`SELECT COALESCE(MAX(id), 0) AS max FROM ${table}`).get().max;
  res.json({
    takenAt: new Date().toISOString(),
    maxUserId: maxId('users'),
    maxRoomId: maxId('rooms'),
    maxChatRoomId: maxId('chat_rooms'),
  });
});

// 현재 DB의 일관된 스냅샷 파일을 스트리밍한다 (better-sqlite3의 backup API 사용 —
// 다른 요청이 동시에 쓰기 중이어도 안전한 복사본을 만든다).
router.get('/snapshot', async (req, res) => {
  const tempPath = path.join(os.tmpdir(), `famil-backup-${Date.now()}.db`);
  try {
    await db.backup(tempPath);
    res.download(tempPath, 'famil-backup.db', (err) => {
      fs.unlink(tempPath, () => {});
      if (err && !res.headersSent) {
        res.status(500).json({ error: '스냅샷 전송 중 오류가 발생했습니다.' });
      }
    });
  } catch (err) {
    fs.unlink(tempPath, () => {});
    res.status(500).json({ error: '스냅샷 생성 중 오류가 발생했습니다.' });
  }
});

const MERGE_TABLES = {
  messages: {
    required: ['senderId', 'receiverId', 'content', 'createdAt'],
    sql: 'INSERT INTO messages (sender_id, receiver_id, content, created_at) VALUES (?, ?, ?, ?)',
    values: (r) => [r.senderId, r.receiverId, r.content, r.createdAt],
  },
  chatRoomMessages: {
    required: ['roomId', 'senderId', 'content', 'createdAt'],
    sql: 'INSERT INTO chat_room_messages (room_id, sender_id, content, created_at) VALUES (?, ?, ?, ?)',
    values: (r) => [r.roomId, r.senderId, r.content, r.createdAt],
  },
  todos: {
    required: ['userId', 'content', 'completed', 'createdAt'],
    sql: 'INSERT INTO todos (user_id, content, completed, completed_date, created_at) VALUES (?, ?, ?, ?, ?)',
    values: (r) => [r.userId, r.content, r.completed ? 1 : 0, r.completedDate || null, r.createdAt],
  },
  schedules: {
    required: ['userId', 'date', 'content', 'createdAt'],
    sql: 'INSERT INTO schedules (user_id, date, content, created_at) VALUES (?, ?, ?, ?)',
    values: (r) => [r.userId, r.date, r.content, r.createdAt],
  },
  suggestions: {
    required: ['content', 'createdAt'],
    sql: 'INSERT INTO suggestions (content, created_at) VALUES (?, ?)',
    values: (r) => [r.content, r.createdAt],
  },
  shoppingItems: {
    required: ['content', 'addedBy', 'createdAt'],
    sql: 'INSERT INTO shopping_items (content, added_by, bought, bought_by, created_at, bought_at) VALUES (?, ?, ?, ?, ?, ?)',
    values: (r) => [r.content, r.addedBy, r.bought ? 1 : 0, r.boughtBy || null, r.createdAt, r.boughtAt || null],
  },
};

// 백업 서버(폰)에서 만들어진, 출입 전부터 있던 사용자/방/단톡방에 대한 새 데이터를
// 주 서버로 되돌려 넣는다. 각 행은 독립적으로 시도하고, 실패한 행은 세지 않고
// 건너뛴다 (예: 참조하는 사용자/방이 그 사이 삭제된 경우).
router.post('/merge-import', (req, res) => {
  const body = req.body || {};
  const imported = {};
  let skipped = 0;

  const transaction = db.transaction(() => {
    for (const [key, spec] of Object.entries(MERGE_TABLES)) {
      const rows = Array.isArray(body[key]) ? body[key] : [];
      let count = 0;
      const stmt = db.prepare(spec.sql);
      for (const row of rows) {
        const hasAllColumns = spec.required.every((c) => row[c] !== undefined);
        if (!hasAllColumns) {
          skipped += 1;
          continue;
        }
        try {
          stmt.run(...spec.values(row));
          count += 1;
        } catch (err) {
          skipped += 1;
        }
      }
      imported[key] = count;
    }
  });
  transaction();

  res.json({ imported, skipped });
});

module.exports = router;
