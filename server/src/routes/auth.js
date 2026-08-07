import { Router } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db.js';
import { hashPassword, verifyPassword, signToken, requireAuth } from '../auth.js';
import { serializeUser } from '../serializers.js';
import { emitToAll } from '../socket.js';

export const authRouter = Router();

const getUserByEmail = db.prepare('SELECT * FROM users WHERE email = ?');
const getUserById = db.prepare('SELECT * FROM users WHERE id = ?');
const insertUser = db.prepare(`
  INSERT INTO users (id, email, password_hash, display_name, role, created_at)
  VALUES (@id, @email, @passwordHash, @displayName, @role, @createdAt)
`);
const getMeta = db.prepare('SELECT value FROM meta WHERE key = ?');
const setMeta = db.prepare('INSERT INTO meta (key, value) VALUES (?, ?)');
const setOnline = db.prepare('UPDATE users SET is_online = ? WHERE id = ?');

const assignRoleTx = db.transaction((email) => {
  const existing = getMeta.get('adminAssigned');
  if (existing) return 'member';
  setMeta.run('adminAssigned', email);
  return 'admin';
});

authRouter.post('/signup', (req, res) => {
  const { email, password, displayName } = req.body || {};
  if (!email || !password || !displayName) {
    return res.status(400).json({ error: 'email, password, displayName은 필수입니다.' });
  }
  if (String(password).length < 6) {
    return res.status(400).json({ error: '비밀번호는 6자 이상이어야 합니다.' });
  }
  const normalizedEmail = String(email).trim().toLowerCase();
  if (getUserByEmail.get(normalizedEmail)) {
    return res.status(409).json({ error: '이미 사용 중인 이메일입니다.' });
  }

  const role = assignRoleTx(normalizedEmail);
  const id = uuidv4();
  const createdAt = new Date().toISOString();
  insertUser.run({
    id,
    email: normalizedEmail,
    passwordHash: hashPassword(password),
    displayName: String(displayName).trim(),
    role,
    createdAt,
  });
  setOnline.run(1, id);

  const user = serializeUser(getUserById.get(id));
  emitToAll('users:changed', {});
  res.status(201).json({ token: signToken(id), user });
});

authRouter.post('/login', (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) {
    return res.status(400).json({ error: 'email, password는 필수입니다.' });
  }
  const row = getUserByEmail.get(String(email).trim().toLowerCase());
  if (!row || !verifyPassword(password, row.password_hash)) {
    return res.status(401).json({ error: '이메일 또는 비밀번호가 올바르지 않습니다.' });
  }
  setOnline.run(1, row.id);
  emitToAll('users:changed', {});
  res.json({ token: signToken(row.id), user: serializeUser(getUserById.get(row.id)) });
});

authRouter.post('/logout', requireAuth, (req, res) => {
  setOnline.run(0, req.uid);
  emitToAll('users:changed', {});
  res.json({ ok: true });
});

authRouter.get('/me', requireAuth, (req, res) => {
  const row = getUserById.get(req.uid);
  if (!row) return res.status(404).json({ error: 'not found' });
  res.json({ user: serializeUser(row) });
});
