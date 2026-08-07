class LotteryResult {
  final int winnerId;
  final String winnerName;
  final List<int> participantIds;
  final String createdAt;

  LotteryResult({
    required this.winnerId,
    required this.winnerName,
    required this.participantIds,
    required this.createdAt,
  });

  factory LotteryResult.fromJson(Map<String, dynamic> json) => LotteryResult(
        winnerId: json['winnerId'] as int,
        winnerName: json['winnerName'] as String,
        participantIds:
            (json['participantIds'] as List<dynamic>).map((e) => e as int).toList(),
        createdAt: json['createdAt'] as String,
      );
}
