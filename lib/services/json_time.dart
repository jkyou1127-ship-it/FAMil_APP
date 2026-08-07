/// 서버는 타임스탬프를 ISO8601 문자열(UTC)로 보낸다.
DateTime? parseTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value as String);
}
