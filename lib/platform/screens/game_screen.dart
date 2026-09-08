import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/leaderboard/leaderboard_service.dart';
import '../../core/models/ai_difficulty.dart';
import '../../core/models/game_over_result.dart';
import '../../core/models/game_session.dart';
import '../../core/models/game_variant.dart';
import '../../core/models/move_record.dart';
import '../../core/plugin/game_plugin.dart';
import '../../core/replay/session_history_store.dart';
import '../theme/app_colors.dart';
import '../widgets/turn_indicator.dart';
import 'replay_screen.dart';

/// Game-agnostic arena screen for Local Pass & Play and VS Computer modes.
class GameScreen extends ConsumerStatefulWidget {
  final GamePlugin plugin;
  final GamePlayMode mode;
  final AIDifficulty? aiDifficulty;
  final String player1Name;
  final String player2Name;
  final String? initialVariantId;

  const GameScreen({
    super.key,
    required this.plugin,
    required this.mode,
    this.aiDifficulty,
    this.player1Name = 'Player X',
    this.player2Name = 'Player O',
    this.initialVariantId,
  });

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late dynamic _gameState;
  GameOverResult? _gameOverResult;
  final List<MoveRecord> _moveHistory = [];
  late String? _currentVariantId;

  int _p1Score = 0;
  int _p2Score = 0;
  bool _isAiThinking = false;
  Timer? _aiTimer;

  @override
  void initState() {
    super.initState();
    _currentVariantId = widget.initialVariantId ??
        (widget.plugin.supportedVariants.isNotEmpty
            ? widget.plugin.supportedVariants.first.id
            : null);
    _startNewRound();
  }

  void _startNewRound([String? variantId]) {
    if (variantId != null) {
      _currentVariantId = variantId;
    }
    _aiTimer?.cancel();
    setState(() {
      _gameState = widget.plugin.initialState(variantId: _currentVariantId);
      _gameOverResult = null;
      _moveHistory.clear();
      _isAiThinking = false;
    });
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    super.dispose();
  }

  bool get _isPlayer1Turn {
    // For tic-tac-toe and standard 2-player turn games, check turn
    try {
      return (_gameState as dynamic).currentTurn == 'X';
    } catch (_) {
      return _moveHistory.length % 2 == 0;
    }
  }

  void _onPlayerMove(dynamic move) {
    if (_gameOverResult != null && _gameOverResult!.isOver) return;
    if (_isAiThinking) return;

    if (!widget.plugin.isValidMove(_gameState, move)) return;

    _applyMove(move, _isPlayer1Turn ? 'p1' : 'p2');
  }

  void _applyMove(dynamic move, String playerId) {
    final nextState = widget.plugin.applyMove(_gameState, move);
    final result = widget.plugin.checkGameOver(nextState);

    final record = MoveRecord(
      moveData: widget.plugin.serializeMove(move),
      playerId: playerId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      sequenceIndex: _moveHistory.length,
    );

    setState(() {
      _gameState = nextState;
      _moveHistory.add(record);
      _gameOverResult = result.isOver ? result : null;
    });

    if (result.isOver) {
      _handleGameOver(result);
    } else if (widget.mode == GamePlayMode.vsAi && !_isPlayer1Turn) {
      // It is now AI's turn
      _triggerAiTurn();
    }
  }

  void _triggerAiTurn() {
    setState(() {
      _isAiThinking = true;
    });

    // Natural delay so animation feels human and smooth (350ms)
    _aiTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;

      final aiMove = widget.plugin.getAIMove(
        _gameState,
        widget.aiDifficulty ?? AIDifficulty.impossible,
      );

      if (aiMove != null && mounted) {
        setState(() {
          _isAiThinking = false;
        });
        _applyMove(aiMove, 'ai');
      } else {
        setState(() {
          _isAiThinking = false;
        });
      }
    });
  }

  void _handleGameOver(GameOverResult result) {
    // Update scores
    if (result.isDraw) {
      // Draw
    } else if (result.winner == 'X') {
      _p1Score++;
    } else if (result.winner == 'O') {
      _p2Score++;
    }

    // Record session for replay
    final session = GameSession(
      sessionId: 'session_${DateTime.now().millisecondsSinceEpoch}',
      gameId: widget.plugin.id,
      variantId: _currentVariantId,
      mode: widget.mode,
      player1Name: widget.player1Name,
      player2Name: widget.player2Name,
      player1Id: 'p1',
      player2Id: widget.mode == GamePlayMode.vsAi ? 'ai' : 'p2',
      moves: List.from(_moveHistory),
      finalResult: result,
      createdAt: DateTime.now(),
    );
    SessionHistoryStore().recordSession(session);

    // Update user stats and leaderboard if logged in
    final auth = AuthService();
    final user = auth.currentUser;
    if (user != null) {
      final isWin = result.winner == 'X';
      final isLoss = result.winner == 'O';
      final isDraw = result.isDraw;

      auth.recordGameResult(
        gameId: widget.plugin.id,
        isWin: isWin,
        isLoss: isLoss,
        isDraw: isDraw,
      );

      final updatedUser = auth.currentUser;
      if (updatedUser != null) {
        final stats = updatedUser.statsForGame(widget.plugin.id);
        LeaderboardService().recordScore(
          gameId: widget.plugin.id,
          uid: updatedUser.uid,
          displayName: updatedUser.displayName,
          avatarUrl: updatedUser.avatarUrl,
          wins: stats.wins,
          losses: stats.losses,
          draws: stats.draws,
          rankScore: stats.rankScore,
          currentStreak: stats.currentStreak,
          isAnonymous: updatedUser.isAnonymous,
        );
      }
    }

    // Show result dialog after win animation completes
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) {
        _showGameOverDialog(result, session);
      }
    });
  }

  void _showGameOverDialog(GameOverResult result, GameSession session) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Game Over',
      barrierColor: Colors.black.withAlpha(180),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        String title;
        Color accentColor;
        IconData icon;

        if (result.isDraw) {
          title = 'DRAW GAME!';
          accentColor = AppColors.textSecondary;
          icon = Icons.handshake_rounded;
        } else if (result.winner == 'X') {
          title = '${widget.player1Name.toUpperCase()} WINS!';
          accentColor = AppColors.playerX;
          icon = Icons.emoji_events_rounded;
        } else {
          title = '${widget.player2Name.toUpperCase()} WINS!';
          accentColor = AppColors.playerO;
          icon = Icons.emoji_events_rounded;
        }

        return Center(
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 340,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: accentColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withAlpha(80),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 54, color: accentColor),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Score: $_p1Score - $_p2Score',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (AuthService().currentUser?.isAnonymous == true) ...[
                      const SizedBox(height: 6),
                      Text(
                        '⚡ Guest match: Not recorded on leaderboard',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.amberAccent.withAlpha(220),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Action buttons
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _startNewRound();
                        },
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('PLAY AGAIN'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReplayScreen(
                                session: session,
                                plugin: widget.plugin,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('WATCH REPLAY'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Back to Lobby',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final variant = widget.plugin.supportedVariants.cast<GameVariant?>().firstWhere(
          (v) => v?.id == _currentVariantId,
          orElse: () => null,
        );
    final variantSuffix = variant != null ? ' • ${variant.label.split(' ').first}' : '';

    final modeLabel = widget.mode == GamePlayMode.local
        ? 'Pass & Play$variantSuffix'
        : 'vs AI (${widget.aiDifficulty?.displayName ?? 'Impossible'})$variantSuffix';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Hero(
          tag: 'game_title_${widget.plugin.id}',
          child: Material(
            color: Colors.transparent,
            child: Text(
              widget.plugin.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accentGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  modeLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // Animated Turn Indicator
                  TurnIndicator(
                    player1Name: widget.player1Name,
                    player2Name: widget.player2Name,
                    player1Symbol: 'X',
                    player2Symbol: 'O',
                    isPlayer1Turn: _isPlayer1Turn,
                    player1Score: _p1Score,
                    player2Score: _p2Score,
                  ),
                  const SizedBox(height: 16),

                  // AI thinking banner indicator
                  if (_isAiThinking)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.playerO.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.playerO.withAlpha(100)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.playerO,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'AI is calculating move...',
                            style: TextStyle(
                              color: AppColors.playerO,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Interactive Board Widget
                  Expanded(
                    child: Center(
                      child: Hero(
                        tag: 'game_board_${widget.plugin.id}',
                        child: widget.plugin.buildBoardWidget(
                          context: context,
                          state: _gameState,
                          onMove: _onPlayerMove,
                          isInteractive: !_isAiThinking &&
                              (_gameOverResult == null ||
                                  !_gameOverResult!.isOver),
                          currentTurnPlayerId:
                              _isPlayer1Turn ? 'p1' : 'p2',
                          localPlayerId: 'p1',
                          gameOverResult: _gameOverResult,
                        ),
                      ),
                    ),
                  ),

                  // Bottom Action Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _startNewRound,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Restart'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_moveHistory.isNotEmpty)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final session = GameSession(
                                  sessionId:
                                      'session_${DateTime.now().millisecondsSinceEpoch}',
                                  gameId: widget.plugin.id,
                                  variantId: _currentVariantId,
                                  mode: widget.mode,
                                  player1Name: widget.player1Name,
                                  player2Name: widget.player2Name,
                                  player1Id: 'p1',
                                  player2Id: 'p2',
                                  moves: List.from(_moveHistory),
                                  finalResult: _gameOverResult,
                                  createdAt: DateTime.now(),
                                );
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ReplayScreen(
                                      session: session,
                                      plugin: widget.plugin,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.history_rounded, size: 18),
                              label: const Text('Replay'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
