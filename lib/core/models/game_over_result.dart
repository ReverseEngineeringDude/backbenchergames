/// Represents the outcome of a game state check.
class GameOverResult {
  final bool isOver;
  final String? winner;
  final bool isDraw;
  final List<int>? winningIndices;

  const GameOverResult({
    required this.isOver,
    this.winner,
    this.isDraw = false,
    this.winningIndices,
  });

  static const notOver = GameOverResult(isOver: false);

  static const draw = GameOverResult(isOver: true, isDraw: true);

  factory GameOverResult.win(String winner, {List<int>? winningIndices}) {
    return GameOverResult(
      isOver: true,
      winner: winner,
      isDraw: false,
      winningIndices: winningIndices,
    );
  }

  Map<String, dynamic> toJson() => {
        'isOver': isOver,
        'winner': winner,
        'isDraw': isDraw,
        'winningIndices': winningIndices,
      };

  factory GameOverResult.fromJson(Map<String, dynamic> json) {
    return GameOverResult(
      isOver: json['isOver'] as bool? ?? false,
      winner: json['winner'] as String?,
      isDraw: json['isDraw'] as bool? ?? false,
      winningIndices: (json['winningIndices'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
    );
  }

  @override
  String toString() =>
      'GameOverResult(isOver: $isOver, winner: $winner, isDraw: $isDraw, winningIndices: $winningIndices)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameOverResult &&
          runtimeType == other.runtimeType &&
          isOver == other.isOver &&
          winner == other.winner &&
          isDraw == other.isDraw;

  @override
  int get hashCode => Object.hash(isOver, winner, isDraw);
}
