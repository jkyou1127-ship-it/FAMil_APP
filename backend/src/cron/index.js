const cron = require('node-cron');
const db = require('../db');
const { kstDateString, KST } = require('../utils/time');

// 매일 자정(KST)에 실행: 완료 후 하루가 지난(전날 이전에 완료된) 할 일을 삭제한다.
function cleanupCompletedTodos() {
  const today = kstDateString();
  db.prepare("DELETE FROM todos WHERE completed = 1 AND completed_date < ?").run(today);
}

function startCronJobs() {
  cron.schedule('0 0 * * *', cleanupCompletedTodos, { timezone: KST });
}

module.exports = { startCronJobs, cleanupCompletedTodos };
