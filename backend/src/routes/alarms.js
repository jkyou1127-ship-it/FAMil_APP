const express = require('express');
const db = require('../db');
const { nowIso } = require('../utils/time');
const { authRequired } = require('../middleware/auth');

const router = express.Router();

const REPEAT_TYPES = ['daily', 'weekly', 'date'];
const TIME_RE = /^([01]\d|2[0-3]):([0-5]\d)$/;

function serialize(row) {
  return {
    id: row.id,
    label: row.label,
    time: row.time,
    repeatType: row.repeat_type,
    repeatDays: row.repeat_days ? JSON.parse(row.repeat_days) : [],
    specificDate: row.specific_date,
    sound: row.sound,
    enabled: !!row.enabled,
    createdAt: row.created_at,
  };
}

router.get('/', authRequired, (req, res) => {
  const rows = db.prepare('SELECT * FROM alarms WHERE user_id = ? ORDER BY time').all(req.user.id);
  res.json({ alarms: rows.map(serialize) });
});

router.post('/', authRequired, (req, res) => {
  const { label, time, repeatType, repeatDays, specificDate, sound } = req.body || {};
  if (!TIME_RE.test(time || '')) {
    return res.status(400).json({ error: '시간은 HH:mm 형식이어야 합니다.' });
  }
  const type = REPEAT_TYPES.includes(repeatType) ? repeatType : 'daily';
  if (type === 'weekly' && (!Array.isArray(repeatDays) || repeatDays.length === 0)) {
    return res.status(400).json({ error: '요일별 반복은 최소 하나의 요일을 선택해야 합니다.' });
  }
  if (type === 'date' && !specificDate) {
    return res.status(400).json({ error: '날짜를 정해서 울리려면 날짜를 선택해야 합니다.' });
  }

  const createdAt = nowIso();
  const info = db
    .prepare(
      `INSERT INTO alarms (user_id, label, time, repeat_type, repeat_days, specific_date, sound, enabled, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)`
    )
    .run(
      req.user.id,
      label || null,
      time,
      type,
      type === 'weekly' ? JSON.stringify(repeatDays) : null,
      type === 'date' ? specificDate || null : null,
      sound || 'tone4',
      createdAt
    );
  const row = db.prepare('SELECT * FROM alarms WHERE id = ?').get(info.lastInsertRowid);
  res.status(201).json({ alarm: serialize(row) });
});

router.patch('/:id', authRequired, (req, res) => {
  const row = db.prepare('SELECT * FROM alarms WHERE id = ? AND user_id = ?').get(
    req.params.id,
    req.user.id
  );
  if (!row) return res.status(404).json({ error: '알람을 찾을 수 없습니다.' });

  const { label, time, repeatType, repeatDays, specificDate, sound, enabled } = req.body || {};
  if (time !== undefined && !TIME_RE.test(time)) {
    return res.status(400).json({ error: '시간은 HH:mm 형식이어야 합니다.' });
  }
  const type = repeatType !== undefined ? repeatType : row.repeat_type;
  if (!REPEAT_TYPES.includes(type)) return res.status(400).json({ error: '올바르지 않은 반복 유형입니다.' });

  db.prepare(
    `UPDATE alarms SET
       label = ?, time = ?, repeat_type = ?, repeat_days = ?, specific_date = ?, sound = ?, enabled = ?
     WHERE id = ?`
  ).run(
    label !== undefined ? label : row.label,
    time !== undefined ? time : row.time,
    type,
    type === 'weekly' ? JSON.stringify(repeatDays !== undefined ? repeatDays : JSON.parse(row.repeat_days || '[]')) : null,
    type === 'date' ? (specificDate !== undefined ? specificDate : row.specific_date) : null,
    sound !== undefined ? sound : row.sound,
    enabled !== undefined ? (enabled ? 1 : 0) : row.enabled,
    row.id
  );
  const updated = db.prepare('SELECT * FROM alarms WHERE id = ?').get(row.id);
  res.json({ alarm: serialize(updated) });
});

router.delete('/:id', authRequired, (req, res) => {
  const info = db.prepare('DELETE FROM alarms WHERE id = ? AND user_id = ?').run(
    req.params.id,
    req.user.id
  );
  if (info.changes === 0) return res.status(404).json({ error: '알람을 찾을 수 없습니다.' });
  res.status(204).end();
});

module.exports = router;
