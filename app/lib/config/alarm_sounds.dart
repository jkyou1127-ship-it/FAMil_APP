class AlarmSoundOption {
  final String id;
  final String label;
  final String asset;
  const AlarmSoundOption(this.id, this.label, this.asset);
}

/// 알람에 사용할 수 있는 기본 제공 사운드 목록. 사용자는 여기서 고르거나
/// (설정 화면에서) 직접 넣은 파일을 사용할 수 있다.
const kAlarmSounds = [
  AlarmSoundOption('tone1', '비프음 (기본)', 'assets/sounds/alarm_tone1.wav'),
  AlarmSoundOption('tone2', '차임벨', 'assets/sounds/alarm_tone2.wav'),
  AlarmSoundOption('tone3', '멜로디', 'assets/sounds/alarm_tone3.wav'),
  AlarmSoundOption('tone4', 'Boss Level Sunrise', 'assets/sounds/alarm_tone4.mp3'),
  AlarmSoundOption('tone5', 'Gold Over Suncheon', 'assets/sounds/alarm_tone5.mp3'),
  AlarmSoundOption('tone6', 'A Valley Awakens', 'assets/sounds/alarm_tone6.mp3'),
];

String alarmAssetFor(String soundId) {
  final match = kAlarmSounds.where((s) => s.id == soundId);
  if (match.isNotEmpty) return match.first.asset;
  return kAlarmSounds.first.asset;
}
