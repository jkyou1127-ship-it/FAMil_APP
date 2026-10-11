const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../db');
const { nowIso } = require('../utils/time');
const { publicUser } = require('../utils/serialize');
const { authRequired } = require('../middleware/auth');
const { mirrorCreate } = require('../utils/firebaseAuthMirror');

const router = express.Router();

function issueToken(user) {
  return jwt.sign({ id: user.id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '30d',
  });
}

// 회원가입: 시스템의 "첫" 계정은 자동으로 관리자 계정이 된다.
router.post('/register', async (req, res) => {
  const { username, password, displayName } = req.body || {};
  if (!username || !password || !displayName) {
    return res.status(400).json({ error: '아이디, 비밀번호, 이름을 모두 입력해주세요.' });
  }
  if (String(password).length < 4) {
    return res.status(400).json({ error: '비밀번호는 4자 이상이어야 합니다.' });
  }

  const existing = db.prepare('SELECT id FROM users WHERE username = ?').get(username);
  if (existing) return res.status(409).json({ error: '이미 사용 중인 아이디입니다.' });

  const userCount = db.prepare('SELECT COUNT(*) AS c FROM users').get().c;
  const isAdmin = userCount === 0 ? 1 : 0;
  const passwordHash = bcrypt.hashSync(password, 10);
  const createdAt = nowIso();

  const info = db
    .prepare(
      `INSERT INTO users (username, password_hash, display_name, is_admin, created_at)
       VALUES (?, ?, ?, ?, ?)`
    )
    .run(username, passwordHash, displayName, isAdmin, createdAt);
  const id = info.lastInsertRowid;

  // PC가 꺼져 있을 때도 Firebase 모드로 같은 아이디/비밀번호로 로그인하고
  // 가족 목록을 볼 수 있도록, 계정을 Firebase Authentication + Firestore
  // 프로필에도 함께 만들어둔다(설정 안 돼 있으면 조용히 건너뛴다 — PC 모드
  // 회원가입 자체는 영향 없음).
  const firebaseUid = await mirrorCreate(id, username, password, displayName, isAdmin);
  if (firebaseUid) {
    db.prepare('UPDATE users SET firebase_uid = ? WHERE id = ?').run(firebaseUid, id);
  }

  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(id);
  const token = issueToken(user);
  res.status(201).json({ token, user: publicUser(user) });
});

router.post('/login', (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) {
    return res.status(400).json({ error: '아이디와 비밀번호를 입력해주세요.' });
  }
  const user = db.prepare('SELECT * FROM users WHERE username = ?').get(username);
  if (!user || !bcrypt.compareSync(password, user.password_hash)) {
    return res.status(401).json({ error: '아이디 또는 비밀번호가 올바르지 않습니다.' });
  }
  const token = issueToken(user);
  res.json({ token, user: publicUser(user) });
});

router.get('/me', authRequired, (req, res) => {
  res.json({ user: publicUser(req.user) });
});

module.exports = router;
