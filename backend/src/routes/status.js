const express = require('express');
const db = require('../db');
const { kstDateString } = require('../utils/time');
const { authRequired } = require('../middleware/auth');

const router = express.Router();

// 상태창: 프로필 사진, 방의 출입 가능/불가능, 온오프라인, 취침여부, 오늘 일정을 보여준다.
router.get('/', authRequired, (req, res) => {
  const users = db.prepare('SELECT * FROM users ORDER BY id').all();
  const today = kstDateString();

  const board = users.map((u) => {
    const room = u.room_id ? db.prepare('SELECT * FROM rooms WHERE id = ?').get(u.room_id) : null;
    const todaySchedules = db
      .prepare('SELECT content FROM schedules WHERE user_id = ? AND date = ? ORDER BY id')
      .all(u.id, today)
      .map((s) => s.content);

    return {
      userId: u.id,
      displayName: u.display_name,
      profilePhoto: u.profile_photo,
      online: !!u.online,
      sleepStatus: u.sleep_status,
      isAdmin: !!u.is_admin,
      room: room && {
        id: room.id,
        name: room.name,
        accessStatus: room.access_status,
        knockEnabled: room.access_status === 'open',
      },
      todaySchedules,
    };
  });

  res.json({ date: today, board });
});

module.exports = router;
