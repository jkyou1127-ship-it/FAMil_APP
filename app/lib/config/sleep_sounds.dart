class SleepSoundOption {
  final String id;
  final String label;
  final String asset;
  const SleepSoundOption(this.id, this.label, this.asset);
}

/// 취침 시 재생할 수 있는 수면 유도 음악 목록. 끝부분이 시작부분과
/// 크로스페이드로 이어지도록 가공되어 있어, 반복 재생해도 이음새가 티나지 않는다.
const kSleepSounds = [
  SleepSoundOption('lullaby1', 'Tide Beneath the Temple', 'assets/sounds/sleep_lullaby.mp3'),
  SleepSoundOption('lullaby2', 'Before the First Light', 'assets/sounds/sleep_lullaby2.mp3'),
];

String sleepSoundAssetFor(String soundId) {
  final match = kSleepSounds.where((s) => s.id == soundId);
  if (match.isNotEmpty) return match.first.asset;
  return kSleepSounds.first.asset;
}
