const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../db');
const { nowIso } = require('../utils/time');
const { publicUser } = require('../utils/serialize');
const { authRequired } = require('../middleware/auth');
const { broadcastStatus } = require('../sockets/io');
const {
  mirrorCreate,
  mirrorLinkExisting,
  verifyIdToken,
  lookupSqlIdByUid,
  readPendingRegistration,
  deletePendingRegistration,
} = require('../utils/firebaseAuthMirror');

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

// PC가 꺼져 있는 동안 Firebase 모드로 가입한 계정을, PC가 다시 켜지고 처음
// 로그인을 시도할 때 실제 SQLite 계정으로 만들어 넣는다. idToken으로
// "이 사람이 정말 그 Firebase 계정의 주인인지"를 서버가 직접 검증하므로,
// 비밀번호는 이 요청에서만 잠깐 쓰이고(로컬 비밀번호 해시를 만드는 용도) 어디에도
// 평문으로 저장되지 않는다.
router.post('/sync-firebase-account', async (req, res) => {
  const { idToken, password } = req.body || {};
  if (!idToken || !password) {
    return res.status(400).json({ error: 'idToken과 password가 필요합니다.' });
  }

  const uid = await verifyIdToken(idToken);
  if (!uid) {
    return res.status(401).json({ error: 'Firebase 인증 정보가 유효하지 않습니다.' });
  }

  // 이미 한 번 동기화된 계정이면(재시도 등) 그냥 기존 계정으로 로그인시킨다.
  const existingSqlId = await lookupSqlIdByUid(uid);
  if (existingSqlId) {
    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(existingSqlId);
    if (user) {
      const token = issueToken(user);
      return res.json({ token, user: publicUser(user) });
    }
  }

  const pending = await readPendingRegistration(uid);
  if (!pending) {
    return res.status(404).json({ error: '대기 중인 Firebase 가입 정보를 찾을 수 없습니다.' });
  }

  // 그 사이 같은 아이디가 로컬에도 생겼을 수 있으니, 겹치면 뒤에 번호를 붙인다.
  let username = pending.username;
  let suffix = 1;
  while (db.prepare('SELECT id FROM users WHERE username = ?').get(username)) {
    suffix += 1;
    username = `${pending.username}_${suffix}`;
  }
  const displayName = pending.displayName || username;
  const passwordHash = bcrypt.hashSync(String(password), 10);
  const createdAt = nowIso();

  const info = db
    .prepare(
      `INSERT INTO users (username, password_hash, display_name, is_admin, firebase_uid, created_at)
       VALUES (?, ?, ?, 0, ?, ?)`
    )
    .run(username, passwordHash, displayName, uid, createdAt);
  const id = info.lastInsertRowid;

  await mirrorLinkExisting(id, uid, { id, username, displayName, isAdmin: false, profilePhoto: null });
  await deletePendingRegistration(uid);

  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(id);
  const token = issueToken(user);
  broadcastStatus();
  res.status(201).json({ token, user: publicUser(user) });
});

module.exports = router;
