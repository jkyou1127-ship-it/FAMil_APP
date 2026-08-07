import { db } from './db.js';

const getRole = db.prepare('SELECT role FROM users WHERE id = ?');

export function isAdmin(uid) {
  const row = getRole.get(uid);
  return row?.role === 'admin';
}

export function requireAdmin(req, res, next) {
  if (!isAdmin(req.uid)) {
    return res.status(403).json({ error: '관리자만 가능합니다.' });
  }
  next();
}
