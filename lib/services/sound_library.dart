/// 앱에 내장된 알람음/수면유도 노래 목록.
class SoundOption {
  final String id;
  final String label;
  final String assetPath;

  const SoundOption({
    required this.id,
    required this.label,
    required this.assetPath,
  });
}

class SoundLibrary {
  SoundLibrary._();

  static const sleepMusic = SoundOption(
    id: 'sleep_calm',
    label: '잔잔한 수면유도 음악',
    assetPath: 'assets/sounds/sleep_calm.wav',
  );

  static const alarmSounds = [
    SoundOption(
      id: 'alarm_classic',
      label: '클래식 알람',
      assetPath: 'assets/sounds/alarm_classic.wav',
    ),
    SoundOption(
      id: 'alarm_melody1',
      label: '멜로디 1 (상쾌한 아침)',
      assetPath: 'assets/sounds/alarm_melody1.wav',
    ),
    SoundOption(
      id: 'alarm_melody2',
      label: '멜로디 2 (경쾌한 차임)',
      assetPath: 'assets/sounds/alarm_melody2.wav',
    ),
  ];

  static SoundOption alarmSoundById(String? id) {
    return alarmSounds.firstWhere(
      (s) => s.id == id,
      orElse: () => alarmSounds.first,
    );
  }
}
