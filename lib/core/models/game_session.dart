import 'game_over_result.dart';
import 'move_record.dart';

enum GamePlayMode {
  local,
  vsAi,
  online,
}

/// Generic session model capturing metadata and the move history of a completed game.
class GameSession {
  final String sessionId;
  final String gameId;
  final String? variantId;
  final GamePlayMode mode;
  final String player1Name;
  final String player2Name;
  final String player1Id;
  final String player2Id;
  final List<MoveRecord> moves;
  final GameOverResult? finalResult;
  final DateTime createdAt;

  const GameSession({
    required this.sessionId,
    required this.gameId,
    this.variantId,
    required this.mode,
    required this.player1Name,
    required this.player2Name,
    required this.player1Id,
    required this.player2Id,
    required this.moves,
    this.finalResult,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'gameId': gameId,
        if (variantId != null) 'variantId': variantId,
        'mode': mode.name,
        'player1Name': player1Name,
        'player2Name': player2Name,
        'player1Id': player1Id,
        'player2Id': player2Id,
        'moves': moves.map((m) => m.toJson()).toList(),
        'finalResult': finalResult?.toJson(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory GameSession.fromJson(Map<String, dynamic> json) {
    return GameSession(
      sessionId: json['sessionId'] as String,
      gameId: json['gameId'] as String,
      variantId: json['variantId'] as String?,
      mode: GamePlayMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => GamePlayMode.local,
      ),
      player1Name: json['player1Name'] as String? ?? 'Player 1',
      player2Name: json['player2Name'] as String? ?? 'Player 2',
      player1Id: json['player1Id'] as String? ?? 'p1',
      player2Id: json['player2Id'] as String? ?? 'p2',
      moves: (json['moves'] as List<dynamic>?)
              ?.map((e) => MoveRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      finalResult: json['finalResult'] != null
          ? GameOverResult.fromJson(
              Map<String, dynamic>.from(json['finalResult'] as Map))
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
