import { Router } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../db.js';
import { requireAuth } from '../auth.js';
import { serializeAlarm } from '../serializers.js';
import { emitToUsers } from '../socket.js';

export const alarmsRouter = Router();
alarmsRouter.use(requireAuth);

const listMine = db.prepare('SELECT * FROM alarms WHERE uid = ?');
const getAlarm = db.prepare('SELECT * FROM alarms WHERE id = ?');
const insertAlarm = db.prepare(`
  INSERT INTO alarms (id, uid, label, hour, minute, repeat, weekdays, once_date, sound_id, custom_sound_path, enabled)
  VALUES (@id, @uid, @label, @hour, @minute, @repeat, @weekdays, @onceDate, @soundId, @customSoundPath, @enabled)
`);
const updateAlarm = db.prepare(`
  UPDATE alarms SET
    label = @label, hour = @hour, minute = @minute, repeat = @repeat,
    weekdays = @weekdays, once_date = @onceDate, sound_id = @soundId,
    custom_sound_path = @customSoundPath, enabled = @enabled
  WHERE id = @id
`);
const setEnabledStmt = db.prepare('UPDATE alarms SET enabled = ? WHERE id = ?');
const deleteAlarm = db.prepare('DELETE FROM alarms WHERE id = ?');

alarmsRouter.get('/', (req, res) => {
  res.json({ alarms: listMine.all(req.uid).map(serializeAlarm) });
});

function fromBody(req, id) {
  const b = req.body || {};
  return {
    id,
    uid: req.uid,
    label: b.label || '알람',
    hour: Number(b.hour ?? 7),
    minute: Number(b.minute ?? 0),
    repeat: b.repeat || 'once',
    weekdays: JSON.stringify(b.weekdays || []),
    onceDate: b.onceDate || null,
    soundId: b.soundId || 'alarm_classic',
    customSoundPath: b.customSoundPath || null,
    enabled: b.enabled === false ? 0 : 1,
  };
}

alarmsRouter.post('/', (req, res) => {
  const id = uuidv4();
  insertAlarm.run(fromBody(req, id));
  emitToUsers([req.uid], 'alarms:changed', {});
  res.status(201).json({ alarm: serializeAlarm(getAlarm.get(id)) });
});

alarmsRouter.put('/:id', (req, res) => {
  const existing = getAlarm.get(req.params.id);
  if (!existing || existing.uid !== req.uid) return res.status(404).json({ error: 'not found' });
  updateAlarm.run(fromBody(req, existing.id));
  emitToUsers([req.uid], 'alarms:changed', {});
  res.json({ alarm: serializeAlarm(getAlarm.get(existing.id)) });
});

alarmsRouter.patch('/:id', (req, res) => {
  const existing = getAlarm.get(req.params.id);
  if (!existing || existing.uid !== req.uid) return res.status(404).json({ error: 'not found' });
  if (typeof req.body?.enabled === 'boolean') {
    setEnabledStmt.run(req.body.enabled ? 1 : 0, existing.id);
  }
  emitToUsers([req.uid], 'alarms:changed', {});
  res.json({ alarm: serializeAlarm(getAlarm.get(existing.id)) });
});

alarmsRouter.delete('/:id', (req, res) => {
  const existing = getAlarm.get(req.params.id);
  if (!existing || existing.uid !== req.uid) return res.status(404).json({ error: 'not found' });
  deleteAlarm.run(existing.id);
  emitToUsers([req.uid], 'alarms:changed', {});
  res.json({ ok: true });
});
