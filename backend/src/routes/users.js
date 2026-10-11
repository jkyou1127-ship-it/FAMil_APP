const express = require('express');
const path = require('path');
const fs = require('fs');
const bcrypt = require('bcryptjs');
const multer = require('multer');
const db = require('../db');
const { nowIso } = require('../utils/time');
const { publicUser } = require('../utils/serialize');
const { authRequired, adminRequired } = require('../middleware/auth');
const { broadcastStatus } = require('../sockets/io');
const { mirrorPasswordChange, mirrorUsernameChange, mirrorDelete } = require('../utils/firebaseAuthMirror');

const router = express.Router();

const uploadDir = path.join(__dirname, '..', '..', 'uploads', 'profiles');
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.jpg';
    cb(null, `user${req.user.id}_${Date.now()}${ext}`);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (!/^image\//.test(file.mimetype)) return cb(new Error('이미지 파일만 업로드할 수 있습니다.'));
    cb(null, true);
  },
});

// 관리자가 소유자를 배정할 때 사용할 전체 사용자 목록, 메신저 상대 선택 등에도 사용된다.
router.get('/', authRequired, (req, res) => {
  const users = db.prepare('SELECT * FROM users ORDER BY id').all().map(publicUser);
  res.json({ users });
});

router.patch('/me', authRequired, (req, res) => {
  const { displayName } = req.body || {};
  if (displayName && String(displayName).trim()) {
    db.prepare('UPDATE users SET display_name = ? WHERE id = ?').run(
      String(displayName).trim(),
      req.user.id
    );
  }
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(req.user.id);
  broadcastStatus();
  res.json({ user: publicUser(user) });
});

router.post('/me/photo', authRequired, (req, res) => {
  upload.single('photo')(req, res, (err) => {
    if (err) return res.status(400).json({ error: err.message });
    if (!req.file) return res.status(400).json({ error: '이미지 파일을 첨부해주세요.' });

    const url = `/uploads/profiles/${req.file.filename}`;
    db.prepare('UPDATE users SET profile_photo = ? WHERE id = ?').run(url, req.user.id);
    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(req.user.id);
    broadcastStatus();
    res.json({ user: publicUser(user) });
  });
});

// 비밀번호 변경: 현재 비밀번호 확인 후 새 비밀번호로 교체한다.
router.patch('/me/password', authRequired, async (req, res) => {
  const { currentPassword, newPassword } = req.body || {};
  if (!currentPassword || !newPassword) {
    return res.status(400).json({ error: '현재 비밀번호와 새 비밀번호를 모두 입력해주세요.' });
  }
  if (!bcrypt.compareSync(String(currentPassword), req.user.password_hash)) {
    return res.status(401).json({ error: '현재 비밀번호가 일치하지 않습니다.' });
  }
  if (String(newPassword).length < 4) {
    return res.status(400).json({ error: '새 비밀번호는 4자 이상이어야 합니다.' });
  }

  const passwordHash = bcrypt.hashSync(String(newPassword), 10);
  db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(passwordHash, req.user.id);
  await mirrorPasswordChange(req.user.firebase_uid, String(newPassword));
  res.status(204).end();
});

// 비밀번호를 잊어버린 사용자를 위해, 관리자가 본인/타인 확인 없이 바로
// 새 비밀번호로 초기화한다. (관리자 본인이 잠겼을 때는 이 API도 쓸 수
// 없으므로 backend/src/scripts/reset-password.js를 대신 사용한다.)
router.patch('/:id/reset-password', authRequired, adminRequired, async (req, res) => {
  const target = db.prepare('SELECT id, firebase_uid FROM users WHERE id = ?').get(req.params.id);
  if (!target) return res.status(404).json({ error: '사용자를 찾을 수 없습니다.' });

  const { newPassword } = req.body || {};
  if (!newPassword || String(newPassword).length < 4) {
    return res.status(400).json({ error: '새 비밀번호는 4자 이상이어야 합니다.' });
  }

  const passwordHash = bcrypt.hashSync(String(newPassword), 10);
  db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(passwordHash, target.id);
  await mirrorPasswordChange(target.firebase_uid, String(newPassword));
  res.status(204).end();
});

// 아이디(로그인용 username) 변경: 비밀번호 확인 후 중복되지 않은 새 아이디로 교체한다.
router.patch('/me/username', authRequired, async (req, res) => {
  const { password, newUsername } = req.body || {};
  const trimmed = newUsername && String(newUsername).trim();
  if (!password || !trimmed) {
    return res.status(400).json({ error: '비밀번호와 새 아이디를 입력해주세요.' });
  }
  if (!bcrypt.compareSync(String(password), req.user.password_hash)) {
    return res.status(401).json({ error: '비밀번호가 일치하지 않습니다.' });
  }

  const existing = db.prepare('SELECT id FROM users WHERE username = ? AND id != ?').get(trimmed, req.user.id);
  if (existing) return res.status(409).json({ error: '이미 사용 중인 아이디입니다.' });

  db.prepare('UPDATE users SET username = ? WHERE id = ?').run(trimmed, req.user.id);
  await mirrorUsernameChange(req.user.firebase_uid, trimmed);
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(req.user.id);
  res.json({ user: publicUser(user) });
});

// 모바일 푸시 알림(FCM)을 받기 위한 기기 토큰을 등록/갱신한다.
router.post('/me/device-token', authRequired, (req, res) => {
  const { token, platform } = req.body || {};
  if (!token) return res.status(400).json({ error: '기기 토큰이 필요합니다.' });

  db.prepare(
    `INSERT INTO device_tokens (user_id, token, platform, created_at) VALUES (?, ?, ?, ?)
     ON CONFLICT(token) DO UPDATE SET user_id = excluded.user_id, platform = excluded.platform`
  ).run(req.user.id, token, platform || 'android', nowIso());

  res.status(204).end();
});

// 회원 탈퇴: 비밀번호 재확인 후 계정과 관련 데이터를 모두 삭제한다.
// 관리자 계정은 시스템에 단 1명만 존재해야 하므로 탈퇴할 수 없다.
router.delete('/me', authRequired, async (req, res) => {
  if (req.user.is_admin) {
    return res.status(403).json({
      error: '관리자 계정은 탈퇴할 수 없습니다. 다른 사용자에게 관리자 권한을 넘기는 기능은 아직 지원되지 않습니다.',
    });
  }

  const { password } = req.body || {};
  if (!password || !bcrypt.compareSync(String(password), req.user.password_hash)) {
    return res.status(401).json({ error: '비밀번호가 일치하지 않습니다.' });
  }

  if (req.user.profile_photo) {
    const filePath = path.join(__dirname, '..', '..', req.user.profile_photo.replace(/^\/+/, ''));
    fs.unlink(filePath, () => {});
  }

  db.prepare('DELETE FROM users WHERE id = ?').run(req.user.id);
  await mirrorDelete(req.user.firebase_uid);

  broadcastStatus();
  res.status(204).end();
});

module.exports = router;
