import 'package:flutter/widgets.dart';
import '../../core/models/ai_difficulty.dart';
import '../../core/models/game_over_result.dart';
import '../../core/models/game_variant.dart';
import '../../core/models/game_session.dart';
import '../../core/plugin/game_plugin.dart';
import 'ai.dart';
import 'board_widget.dart';
import 'logic.dart';

/// GamePlugin implementation for Tic-Tac-Toe.
class TicTacToePlugin extends GamePlugin<TicTacToeState, TicTacToeMove> {
  final TicTacToeAI _ai;

  TicTacToePlugin([TicTacToeAI? ai]) : _ai = ai ?? TicTacToeAI();

  @override
  String get id => 'tic_tac_toe';

  @override
  String get displayName => 'Tic-Tac-Toe';

  @override
  String get description =>
      'Neon grid duel. Play 3x3 (3 dots), 6x6 (4 dots), or 9x9 (5 dots) to win!';

  @override
  int get minPlayers => 2;

  @override
  int get maxPlayers => 2;

  @override
  List<AIDifficulty> get supportedDifficulties => AIDifficulty.values;

  @override
  List<GameVariant> get supportedVariants => const [
        GameVariant(
          id: '3x3',
          label: '3x3 (3 dots)',
          description: 'Classic 3x3 grid — 3 dots to win',
        ),
        GameVariant(
          id: '6x6',
          label: '6x6 (4 dots)',
          description: 'Tactical 6x6 grid — 4 dots to win',
        ),
        GameVariant(
          id: '9x9',
          label: '9x9 (5 dots)',
          description: 'Grand 9x9 grid — 5 dots to win',
        ),
      ];

  @override
  String? resolveVariantForSession(GameSession session) {
    if (session.variantId != null && session.variantId!.isNotEmpty) {
      return session.variantId;
    }
    // Infer variant from the maximum move index in session.moves
    int maxIndex = -1;
    for (final m in session.moves) {
      final idx = m.moveData['index'];
      if (idx is int && idx > maxIndex) {
        maxIndex = idx;
      }
    }
    if (maxIndex >= 36) return '9x9';
    if (maxIndex >= 9) return '6x6';
    return '3x3';
  }

  @override
  TicTacToeState initialState({String? variantId}) {
    int size = 3;
    if (variantId != null) {
      if (variantId == '6x6' || variantId.contains('6')) {
        size = 6;
      } else if (variantId == '9x9' || variantId.contains('9')) {
        size = 9;
      }
    }
    return TicTacToeLogic.initialState(gridSize: size);
  }

  @override
  TicTacToeState applyMove(TicTacToeState state, TicTacToeMove move) =>
      TicTacToeLogic.applyMove(state, move);

  @override
  bool isValidMove(TicTacToeState state, TicTacToeMove move) =>
      TicTacToeLogic.isValidMove(state, move);

  @override
  GameOverResult checkGameOver(TicTacToeState state) =>
      TicTacToeLogic.checkGameOver(state);

  @override
  TicTacToeMove? getAIMove(TicTacToeState state, AIDifficulty difficulty) =>
      _ai.getNextMove(state, difficulty);

  @override
  Map<String, dynamic> serializeState(TicTacToeState state) => state.toJson();

  @override
  TicTacToeState deserializeState(Map<String, dynamic> json) =>
      TicTacToeState.fromJson(json);

  @override
  Map<String, dynamic> serializeMove(TicTacToeMove move) => move.toJson();

  @override
  TicTacToeMove deserializeMove(Map<String, dynamic> json) =>
      TicTacToeMove.fromJson(json);

  @override
  Widget buildBoardWidget({
    required BuildContext context,
    required TicTacToeState state,
    required void Function(TicTacToeMove move) onMove,
    required bool isInteractive,
    required String? currentTurnPlayerId,
    required String? localPlayerId,
    TicTacToeMove? lastMove,
    GameOverResult? gameOverResult,
    bool isReplay = false,
  }) {
    return TicTacToeBoardWidget(
      key: const ValueKey('tic_tac_toe_board'),
      state: state,
      onMove: onMove,
      isInteractive: isInteractive,
      gameOverResult: gameOverResult,
      isReplay: isReplay,
    );
  }
}
