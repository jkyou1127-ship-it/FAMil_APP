const express = require('express');
const db = require('../db');
const { nowIso, dayjs } = require('../utils/time');
const { authRequired } = require('../middleware/auth');
const { broadcastStatus } = require('../sockets/io');

const router = express.Router();

function serializeRecord(row) {
  const durationMinutes = row.wake_at
    ? Math.round(dayjs(row.wake_at).diff(dayjs(row.sleep_at), 'minute', true))
    : null;
  return {
    id: row.id,
    sleepAt: row.sleep_at,
    wakeAt: row.wake_at,
    durationMinutes,
  };
}

// 취침: 시간이 기록되고 상태창에 취침 상태가 표시된다. (수면 유도 노래 재생 여부는 sleepSoundEnabled 설정을 따름)
router.post('/start', authRequired, (req, res) => {
  const open = db
    .prepare('SELECT id FROM sleep_records WHERE user_id = ? AND wake_at IS NULL')
    .get(req.user.id);
  if (open) return res.status(409).json({ error: '이미 취침 중입니다. 먼저 기상해주세요.' });

  const sleepAt = nowIso();
  const info = db
    .prepare('INSERT INTO sleep_records (user_id, sleep_at, created_at) VALUES (?, ?, ?)')
    .run(req.user.id, sleepAt, sleepAt);
  db.prepare("UPDATE users SET sleep_status = 'sleeping' WHERE id = ?").run(req.user.id);

  broadcastStatus();
  const record = db.prepare('SELECT * FROM sleep_records WHERE id = ?').get(info.lastInsertRowid);
  res.status(201).json({ record: serializeRecord(record) });
});

// 기상: 기상시간이 기록되고 취침시간으로부터 잔 시간이 계산된다.
router.post('/wake', authRequired, (req, res) => {
  const open = db
    .prepare('SELECT * FROM sleep_records WHERE user_id = ? AND wake_at IS NULL ORDER BY id DESC LIMIT 1')
    .get(req.user.id);
  if (!open) return res.status(409).json({ error: '취침 기록이 없습니다.' });

  const wakeAt = nowIso();
  db.prepare('UPDATE sleep_records SET wake_at = ? WHERE id = ?').run(wakeAt, open.id);
  db.prepare("UPDATE users SET sleep_status = 'awake' WHERE id = ?").run(req.user.id);

  broadcastStatus();
  const record = db.prepare('SELECT * FROM sleep_records WHERE id = ?').get(open.id);
  res.json({ record: serializeRecord(record) });
});

// 수면 유도 노래 on/off: 한번 off로 바꾸면 다시 on으로 바꾸기 전까지 계속 off로 유지된다.
// soundId를 함께 보내면 재생할 곡도 함께 바꾼다.
router.patch('/sound', authRequired, (req, res) => {
  const { enabled, soundId } = req.body || {};
  if (soundId) {
    db.prepare('UPDATE users SET sleep_sound_enabled = ?, sleep_sound_id = ? WHERE id = ?').run(
      enabled ? 1 : 0,
      String(soundId),
      req.user.id
    );
  } else {
    db.prepare('UPDATE users SET sleep_sound_enabled = ? WHERE id = ?').run(
      enabled ? 1 : 0,
      req.user.id
    );
  }
  const user = db.prepare('SELECT sleep_sound_enabled, sleep_sound_id FROM users WHERE id = ?').get(req.user.id);
  res.json({ sleepSoundEnabled: !!user.sleep_sound_enabled, sleepSoundId: user.sleep_sound_id });
});

router.get('/records', authRequired, (req, res) => {
  const rows = db
    .prepare('SELECT * FROM sleep_records WHERE user_id = ? ORDER BY sleep_at DESC LIMIT 30')
    .all(req.user.id);
  res.json({ records: rows.map(serializeRecord) });
});

module.exports = router;
