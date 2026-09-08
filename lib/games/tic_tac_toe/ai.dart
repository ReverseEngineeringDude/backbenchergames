import 'dart:math';
import '../../core/models/ai_difficulty.dart';
import 'logic.dart';

/// Minimax AI engine for Tic-Tac-Toe supporting 3x3, 6x6, and 9x9 grids.
class TicTacToeAI {
  final Random _random;

  TicTacToeAI([Random? random]) : _random = random ?? Random();

  /// Computes the next best move for [difficulty].
  TicTacToeMove? getNextMove(
    TicTacToeState state,
    AIDifficulty difficulty,
  ) {
    final available = TicTacToeLogic.getAvailableMoves(state);
    if (available.isEmpty) return null;

    final aiPlayer = state.currentTurn;
    final opponent = aiPlayer == 'X' ? 'O' : 'X';

    switch (difficulty) {
      case AIDifficulty.easy:
        return _getRandomMove(state, available, aiPlayer);

      case AIDifficulty.medium:
        // 30% chance of deliberate suboptimal/random move, 70% optimal
        if (_random.nextDouble() < 0.30) {
          return _getRandomMove(state, available, aiPlayer);
        }
        return _getBestMove(state, available, aiPlayer, opponent);

      case AIDifficulty.impossible:
        return _getBestMove(state, available, aiPlayer, opponent);
    }
  }

  TicTacToeMove _getRandomMove(
    TicTacToeState state,
    List<int> available,
    String player,
  ) {
    final randomIndex = available[_random.nextInt(available.length)];
    return TicTacToeMove(index: randomIndex, player: player);
  }

  TicTacToeMove _getBestMove(
    TicTacToeState state,
    List<int> available,
    String aiPlayer,
    String opponent,
  ) {
    // 1. Immediate Win: If AI can win in 1 move, take it!
    for (final moveIndex in available) {
      final nextState = TicTacToeLogic.applyMove(
        state,
        TicTacToeMove(index: moveIndex, player: aiPlayer),
      );
      if (TicTacToeLogic.checkGameOver(nextState).winner == aiPlayer) {
        return TicTacToeMove(index: moveIndex, player: aiPlayer);
      }
    }

    // 2. Immediate Block: If opponent can win next move, block it!
    for (final moveIndex in available) {
      final hypotheticalOpponentState = TicTacToeLogic.applyMove(
        state.copyWith(currentTurn: opponent),
        TicTacToeMove(index: moveIndex, player: opponent),
      );
      if (TicTacToeLogic.checkGameOver(hypotheticalOpponentState).winner == opponent) {
        return TicTacToeMove(index: moveIndex, player: aiPlayer);
      }
    }

    // 3. Opening move: if empty, play near center or corners
    if (available.length == state.totalCells) {
      if (state.gridSize == 3) {
        const openingMoves = [0, 2, 4, 6, 8];
        final pick = openingMoves[_random.nextInt(openingMoves.length)];
        return TicTacToeMove(index: pick, player: aiPlayer);
      } else {
        final centerRow = state.gridSize ~/ 2;
        final centerCol = state.gridSize ~/ 2;
        return TicTacToeMove(
          index: centerRow * state.gridSize + centerCol,
          player: aiPlayer,
        );
      }
    }

    // Depth limits based on grid size to prevent lag while remaining unbeatable/expert
    final maxDepth = state.gridSize == 3 ? 9 : (state.gridSize == 6 ? 4 : 3);

    // Filter candidate moves for large boards to optimize search
    final candidates = state.gridSize == 3 ? available : _getCandidateMoves(state, available);

    int bestScore = -10000000;
    int bestMove = candidates.first;

    for (final moveIndex in candidates) {
      final nextState = TicTacToeLogic.applyMove(
        state,
        TicTacToeMove(index: moveIndex, player: aiPlayer),
      );

      final score = _minimax(
        state: nextState,
        depth: 1,
        maxDepth: maxDepth,
        isMaximizing: false,
        aiPlayer: aiPlayer,
        opponent: opponent,
        alpha: -10000000,
        beta: 10000000,
      );

      if (score > bestScore) {
        bestScore = score;
        bestMove = moveIndex;
      }
    }

    return TicTacToeMove(index: bestMove, player: aiPlayer);
  }

  int _minimax({
    required TicTacToeState state,
    required int depth,
    required int maxDepth,
    required bool isMaximizing,
    required String aiPlayer,
    required String opponent,
    required int alpha,
    required int beta,
  }) {
    final gameOver = TicTacToeLogic.checkGameOver(state);
    if (gameOver.isOver) {
      if (gameOver.winner == aiPlayer) {
        return 1000000 - depth;
      } else if (gameOver.winner == opponent) {
        return depth - 1000000;
      } else {
        return 0; // Draw
      }
    }

    if (depth >= maxDepth) {
      return _evaluateState(state, aiPlayer, opponent);
    }

    final available = TicTacToeLogic.getAvailableMoves(state);
    final candidates = state.gridSize == 3 ? available : _getCandidateMoves(state, available);

    if (candidates.isEmpty) return 0;

    if (isMaximizing) {
      int maxEval = -10000000;
      for (final moveIndex in candidates) {
        final nextState = TicTacToeLogic.applyMove(
          state,
          TicTacToeMove(index: moveIndex, player: aiPlayer),
        );
        final evaluation = _minimax(
          state: nextState,
          depth: depth + 1,
          maxDepth: maxDepth,
          isMaximizing: false,
          aiPlayer: aiPlayer,
          opponent: opponent,
          alpha: alpha,
          beta: beta,
        );
        maxEval = max(maxEval, evaluation);
        alpha = max(alpha, evaluation);
        if (beta <= alpha) break;
      }
      return maxEval;
    } else {
      int minEval = 10000000;
      for (final moveIndex in candidates) {
        final nextState = TicTacToeLogic.applyMove(
          state,
          TicTacToeMove(index: moveIndex, player: opponent),
        );
        final evaluation = _minimax(
          state: nextState,
          depth: depth + 1,
          maxDepth: maxDepth,
          isMaximizing: true,
          aiPlayer: aiPlayer,
          opponent: opponent,
          alpha: alpha,
          beta: beta,
        );
        minEval = min(minEval, evaluation);
        beta = min(beta, evaluation);
        if (beta <= alpha) break;
      }
      return minEval;
    }
  }

  /// Filters candidate moves to cells within distance 1 (or 2) of any placed piece.
  List<int> _getCandidateMoves(TicTacToeState state, List<int> available) {
    final candidateSet = <int>{};
    final n = state.gridSize;

    for (int i = 0; i < state.totalCells; i++) {
      if (state.board[i] != null) {
        final r = i ~/ n;
        final c = i % n;

        for (int dr = -2; dr <= 2; dr++) {
          for (int dc = -2; dc <= 2; dc++) {
            final nr = r + dr;
            final nc = c + dc;
            if (nr >= 0 && nr < n && nc >= 0 && nc < n) {
              final idx = nr * n + nc;
              if (state.board[idx] == null) {
                candidateSet.add(idx);
              }
            }
          }
        }
      }
    }

    if (candidateSet.isEmpty) return available;
    return candidateSet.toList();
  }

  /// Heuristic evaluation of a board state for when maxDepth is reached.
  int _evaluateState(TicTacToeState state, String aiPlayer, String opponent) {
    final winLines = TicTacToeLogic.getWinLines(state.gridSize, state.winLength);
    int totalScore = 0;
    final k = state.winLength;

    for (final line in winLines) {
      int aiCount = 0;
      int opponentCount = 0;

      for (final idx in line) {
        final mark = state.board[idx];
        if (mark == aiPlayer) {
          aiCount++;
        } else if (mark == opponent) {
          opponentCount++;
        }
      }

      // If both players have pieces in this line, it's blocked and useless
      if (aiCount > 0 && opponentCount > 0) continue;

      if (aiCount > 0) {
        if (aiCount == k) return 1000000;
        if (aiCount == k - 1) totalScore += 50000;
        if (aiCount == k - 2) totalScore += 400;
        if (aiCount == k - 3) totalScore += 30;
      } else if (opponentCount > 0) {
        if (opponentCount == k) return -1000000;
        if (opponentCount == k - 1) totalScore -= 70000; // Block opponent's near-win heavily
        if (opponentCount == k - 2) totalScore -= 500;
        if (opponentCount == k - 3) totalScore -= 40;
      }
    }

    return totalScore;
  }
}
