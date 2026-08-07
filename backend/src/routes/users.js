const express = require('express');
const path = require('path');
const multer = require('multer');
const db = require('../db');
const { publicUser } = require('../utils/serialize');
const { authRequired, adminRequired } = require('../middleware/auth');
const { broadcastStatus } = require('../sockets/io');

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

module.exports = router;
