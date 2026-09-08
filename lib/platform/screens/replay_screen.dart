import 'package:flutter/material.dart';
import '../../core/models/game_session.dart';
import '../../core/plugin/game_plugin.dart';
import '../../core/replay/replay_controller.dart';
import '../../core/replay/replay_scrubber.dart';
import '../theme/app_colors.dart';
import '../widgets/turn_indicator.dart';

/// Generic replay screen for any game session.
class ReplayScreen extends StatefulWidget {
  final GameSession session;
  final GamePlugin plugin;

  const ReplayScreen({
    super.key,
    required this.session,
    required this.plugin,
  });

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  late final ReplayController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ReplayController(
      session: widget.session,
      plugin: widget.plugin,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.plugin.displayName} Replay',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              '${widget.session.player1Name} vs ${widget.session.player2Name}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final state = _controller.currentState;
                  final gameOver = _controller.currentGameOverResult;

                  // Determine active turn for turn indicator
                  bool isP1Turn = true;
                  try {
                    isP1Turn = (state as dynamic).currentTurn == 'X';
                  } catch (_) {
                    isP1Turn = _controller.currentStepIndex % 2 == 0;
                  }

                  return Column(
                    children: [
                      // Turn indicator showing whose turn at this point in the replay
                      TurnIndicator(
                        player1Name: widget.session.player1Name,
                        player2Name: widget.session.player2Name,
                        isPlayer1Turn: isP1Turn,
                        player1Score: widget.session.finalResult?.winner == 'X' ? 1 : 0,
                        player2Score: widget.session.finalResult?.winner == 'O' ? 1 : 0,
                      ),
                      const SizedBox(height: 16),

                      // Animated Board rendering the current step
                      Expanded(
                        child: Center(
                          child: widget.plugin.buildBoardWidget(
                            context: context,
                            state: state,
                            onMove: (_) {}, // Replay is not interactive
                            isInteractive: false,
                            currentTurnPlayerId: isP1Turn ? 'p1' : 'p2',
                            localPlayerId: 'p1',
                            gameOverResult: gameOver,
                            isReplay: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Generic Replay Scrubber Controls
                      ReplayScrubber(controller: _controller),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
