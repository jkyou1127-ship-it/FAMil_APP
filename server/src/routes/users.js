import { Router } from 'express';
import { db } from '../db.js';
import { requireAuth } from '../auth.js';
import { serializeUser } from '../serializers.js';
import { emitToAll } from '../socket.js';

export const usersRouter = Router();
usersRouter.use(requireAuth);

const listUsers = db.prepare('SELECT * FROM users ORDER BY display_name');
const getUserById = db.prepare('SELECT * FROM users WHERE id = ?');
const updateSelf = db.prepare(`
  UPDATE users SET
    display_name = COALESCE(@displayName, display_name),
    access_open = COALESCE(@accessOpen, access_open),
    is_sleeping = COALESCE(@isSleeping, is_sleeping),
    sleep_started_at = CASE WHEN @sleepStartedAtSet = 1 THEN @sleepStartedAt ELSE sleep_started_at END,
    sleep_music_enabled = COALESCE(@sleepMusicEnabled, sleep_music_enabled),
    profile_photo_url = COALESCE(@profilePhotoUrl, profile_photo_url)
  WHERE id = @id
`);

usersRouter.get('/', (req, res) => {
  res.json({ users: listUsers.all().map(serializeUser) });
});

usersRouter.patch('/me', (req, res) => {
  const b = req.body || {};
  updateSelf.run({
    id: req.uid,
    displayName: b.displayName ?? null,
    accessOpen: b.accessOpen === undefined ? null : (b.accessOpen ? 1 : 0),
    isSleeping: b.isSleeping === undefined ? null : (b.isSleeping ? 1 : 0),
    sleepStartedAtSet: Object.prototype.hasOwnProperty.call(b, 'sleepStartedAt') ? 1 : 0,
    sleepStartedAt: b.sleepStartedAt ?? null,
    sleepMusicEnabled: b.sleepMusicEnabled === undefined ? null : (b.sleepMusicEnabled ? 1 : 0),
    profilePhotoUrl: b.profilePhotoUrl ?? null,
  });
  emitToAll('users:changed', {});
  res.json({ user: serializeUser(getUserById.get(req.uid)) });
});
