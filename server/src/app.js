import express from 'express';
import cors from 'cors';

import { authRouter } from './routes/auth.js';
import { usersRouter } from './routes/users.js';
import { roomsRouter } from './routes/rooms.js';
import { knocksRouter } from './routes/knocks.js';
import { todosRouter } from './routes/todos.js';
import { schedulesRouter } from './routes/schedules.js';
import { suggestionsRouter } from './routes/suggestions.js';
import { chatsRouter } from './routes/chats.js';
import { drawsRouter } from './routes/draws.js';
import { sleepSessionsRouter } from './routes/sleepSessions.js';
import { alarmsRouter } from './routes/alarms.js';

export function createApp() {
  const app = express();
  app.use(cors());
  app.use(express.json());

  app.get('/health', (req, res) => res.json({ ok: true }));

  app.use('/auth', authRouter);
  app.use('/users', usersRouter);
  app.use('/rooms', roomsRouter);
  app.use('/knocks', knocksRouter);
  app.use('/todos', todosRouter);
  app.use('/schedules', schedulesRouter);
  app.use('/suggestions', suggestionsRouter);
  app.use('/chats', chatsRouter);
  app.use('/draws', drawsRouter);
  app.use('/sleep-sessions', sleepSessionsRouter);
  app.use('/alarms', alarmsRouter);

  app.use((req, res) => res.status(404).json({ error: 'not found' }));
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    console.error(err);
    res.status(500).json({ error: 'internal_error' });
  });

  return app;
}
