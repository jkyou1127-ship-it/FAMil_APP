const dayjs = require('dayjs');
const utc = require('dayjs/plugin/utc');
const timezone = require('dayjs/plugin/timezone');

dayjs.extend(utc);
dayjs.extend(timezone);

const KST = 'Asia/Seoul';

/** Current time as a dayjs object in KST. */
function nowKst() {
  return dayjs().tz(KST);
}

/** Current time as an ISO-8601 string (UTC instant, safe for storage/sorting). */
function nowIso() {
  return dayjs().toISOString();
}

/** KST calendar date string (YYYY-MM-DD) for a given instant (defaults to now). */
function kstDateString(instant) {
  return (instant ? dayjs(instant) : dayjs()).tz(KST).format('YYYY-MM-DD');
}

/** Korean-style날짜 문자열 (년/월/일) for a given instant (defaults to now). */
function krDateString(instant) {
  return (instant ? dayjs(instant) : dayjs()).tz(KST).format('YYYY/M/D');
}

/** Weekday index in KST, 0=Sunday..6=Saturday. */
function kstWeekday(instant) {
  return (instant ? dayjs(instant) : dayjs()).tz(KST).day();
}

module.exports = { dayjs, KST, nowKst, nowIso, kstDateString, krDateString, kstWeekday };
