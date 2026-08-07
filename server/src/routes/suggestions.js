import { Router } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db.js';
import { requireAuth } from '../auth.js';
import { serializeSuggestion } from '../serializers.js';
import { emitToAll } from '../socket.js';

export const suggestionsRouter = Router();
suggestionsRouter.use(requireAuth);

const listAll = db.prepare('SELECT * FROM suggestions ORDER BY created_at DESC');
// 익명성 보장을 위해 작성자(uid)는 저장하지 않는다.
const insertSuggestion = db.prepare('INSERT INTO suggestions (id, text, created_at) VALUES (?, ?, ?)');

suggestionsRouter.get('/', (req, res) => {
  res.json({ suggestions: listAll.all().map(serializeSuggestion) });
});

suggestionsRouter.post('/', (req, res) => {
  const text = (req.body?.text || '').trim();
  if (!text) return res.status(400).json({ error: '내용을 입력하세요.' });
  const id = uuidv4();
  insertSuggestion.run(id, text, new Date().toISOString());
  emitToAll('suggestions:changed', {});
  res.status(201).json({ ok: true });
});
