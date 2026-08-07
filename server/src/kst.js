// 한국 표준시(KST, UTC+9) 유틸리티. 저장되는 타임스탬프는 항상 실제 UTC
// 순간(instant)이며, 날짜 비교/표시가 필요할 때만 KST로 변환한다.

const OFFSET_MS = 9 * 60 * 60 * 1000;

function pad(n) {
  return String(n).padStart(2, '0');
}

function shiftToKst(date) {
  return new Date(date.getTime() + OFFSET_MS);
}

/** 'yyyy/MM/dd' (KST 기준 벽시계 날짜). */
export function kstDateString(date = new Date()) {
  const k = shiftToKst(date);
  return `${k.getUTCFullYear()}/${pad(k.getUTCMonth() + 1)}/${pad(k.getUTCDate())}`;
}

export function isSameKstDay(a, b) {
  return kstDateString(a) === kstDateString(b);
}
