import { Router } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db.js';
import { requireAuth } from '../auth.js';
import { serializeTodo } from '../serializers.js';
import { emitToUsers } from '../socket.js';
import { isSameKstDay } from '../kst.js';

export const todosRouter = Router();
todosRouter.use(requireAuth);

const listMine = db.prepare('SELECT * FROM todos WHERE uid = ? ORDER BY created_at DESC');
const getTodo = db.prepare('SELECT * FROM todos WHERE id = ?');
const insertTodo = db.prepare(
  'INSERT INTO todos (id, uid, text, created_at) VALUES (?, ?, ?, ?)'
);
const setDoneStmt = db.prepare('UPDATE todos SET done = ?, done_at = ? WHERE id = ?');
const deleteTodo = db.prepare('DELETE FROM todos WHERE id = ?');
const deleteStale = db.prepare('DELETE FROM todos WHERE id = ?');

function cleanupStale(uid) {
  const now = new Date();
  for (const row of listMine.all(uid)) {
    if (row.done && row.done_at && !isSameKstDay(new Date(row.done_at), now)) {
      deleteStale.run(row.id);
    }
  }
}

todosRouter.get('/', (req, res) => {
  cleanupStale(req.uid);
  res.json({ todos: listMine.all(req.uid).map(serializeTodo) });
});

todosRouter.post('/', (req, res) => {
  const text = (req.body?.text || '').trim();
  if (!text) return res.status(400).json({ error: '내용을 입력하세요.' });
  const id = uuidv4();
  insertTodo.run(id, req.uid, text, new Date().toISOString());
  emitToUsers([req.uid], 'todos:changed', {});
  res.status(201).json({ todo: serializeTodo(getTodo.get(id)) });
});

todosRouter.patch('/:id', (req, res) => {
  const todo = getTodo.get(req.params.id);
  if (!todo || todo.uid !== req.uid) return res.status(404).json({ error: 'not found' });
  const done = !!req.body?.done;
  setDoneStmt.run(done ? 1 : 0, done ? new Date().toISOString() : null, todo.id);
  emitToUsers([req.uid], 'todos:changed', {});
  res.json({ todo: serializeTodo(getTodo.get(todo.id)) });
});

todosRouter.delete('/:id', (req, res) => {
  const todo = getTodo.get(req.params.id);
  if (!todo || todo.uid !== req.uid) return res.status(404).json({ error: 'not found' });
  deleteTodo.run(todo.id);
  emitToUsers([req.uid], 'todos:changed', {});
  res.json({ ok: true });
});
