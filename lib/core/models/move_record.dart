/// Generic record representing a single move made in any game session.
class MoveRecord {
  final Map<String, dynamic> moveData;
  final String playerId;
  final int timestamp;
  final int sequenceIndex;

  const MoveRecord({
    required this.moveData,
    required this.playerId,
    required this.timestamp,
    required this.sequenceIndex,
  });

  Map<String, dynamic> toJson() => {
        'moveData': moveData,
        'playerId': playerId,
        'timestamp': timestamp,
        'sequenceIndex': sequenceIndex,
      };

  factory MoveRecord.fromJson(Map<String, dynamic> json) {
    return MoveRecord(
      moveData: Map<String, dynamic>.from(json['moveData'] as Map),
      playerId: json['playerId'] as String,
      timestamp: json['timestamp'] as int? ?? 0,
      sequenceIndex: json['sequenceIndex'] as int? ?? 0,
    );
  }

  @override
  String toString() =>
      'MoveRecord(seq: $sequenceIndex, player: $playerId, data: $moveData)';
}
