import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/lan_room.dart';
import '../../core/plugin/game_plugin.dart';
import '../../core/rooms/lan_room_service.dart';
import '../theme/app_colors.dart';
import '../widgets/turn_indicator.dart';

/// Game screen for LAN / Wi-Fi Direct multiplayer.
/// Works for BOTH host and guest sides — [isHost] distinguishes them.
class LanGameScreen extends StatefulWidget {
  final LanRoom initialRoom;
  final GamePlugin plugin;
  final bool isHost;
  final String localUid;
  final String localDisplayName;
  final LanRoomService service;

  const LanGameScreen({
    super.key,
    required this.initialRoom,
    required this.plugin,
    required this.isHost,
    required this.localUid,
    required this.localDisplayName,
    required this.service,
  });

  @override
  State<LanGameScreen> createState() => _LanGameScreenState();
}

class _LanGameScreenState extends State<LanGameScreen> {
  LanRoom? _room;
  StreamSubscription<LanRoom>? _sub;
  bool _hasShownDismantledDialog = false;
  bool _isSubmitting = false;
  bool _isExplicitlyLeaving = false;

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    _sub = widget.service.roomStream.listen(_onRoomUpdate);
  }

  void _onRoomUpdate(LanRoom room) {
    if (!mounted) return;
    setState(() => _room = room);
    if (room.isDismantled && !_hasShownDismantledDialog) {
      _hasShownDismantledDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDismantledDialog(room.dismantledReason ?? 'The session has ended.');
      });
    }
  }

  void _showDismantledDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Session Ended', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Text(reason, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // dialog
              Navigator.of(context).pop(); // game screen
            },
            child: const Text('Back to Lobby'),
          ),
        ],
      ),
    );
  }

  void _onMove(dynamic move) async {
    final room = _room;
    if (room == null || room.isDismantled || _isSubmitting) return;

    final gameState = widget.plugin.deserializeState(room.stateData);
    if (!widget.plugin.isValidMove(gameState, move)) return;

    setState(() => _isSubmitting = true);

    try {
      final serialized = widget.plugin.serializeMove(move);
      final nextState = widget.plugin.applyMove(gameState, move);
      final nextStateData = widget.plugin.serializeState(nextState);

      final updated = room.copyWith(stateData: nextStateData);

      if (widget.isHost) {
        // Host applies move immediately and broadcasts
        widget.service.broadcastState(updated);
        setState(() => _room = updated);
      } else {
        // Guest sends move to host and waits for broadcast
        widget.service.sendMove(serialized);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _confirmLeave() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Game?'),
        content: const Text('This will end the session for both players.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              _isExplicitlyLeaving = true;
              Navigator.of(context).pop(); // dialog
              widget.service.dismantle(reason: 'Opponent left the game');
              Navigator.of(context).pop(); // game screen
            },
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (!_isExplicitlyLeaving && !(_room?.isDismantled ?? false)) {
      widget.service.dismantle(reason: 'Opponent left the game');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    if (room == null || room.isDismantled) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                room?.dismantledReason ?? 'Session ended.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Lobby'),
              ),
            ],
          ),
        ),
      );
    }

    if (room.isWaiting) {
      return _buildWaiting(room);
    }

    return _buildGame(room);
  }

  Widget _buildWaiting(LanRoom room) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _confirmLeave,
          ),
          title: const Text('LAN Room', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.playerX, width: 2),
                        boxShadow: [
                          BoxShadow(color: AppColors.playerXGlow, blurRadius: 20, spreadRadius: 2),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'LAN ROOM CODE',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            room.roomCode,
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 6,
                              color: AppColors.playerX,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${room.hostIp}:${room.hostPort}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.playerX,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: '${room.hostIp}:${room.hostPort}'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('IP:Port copied to clipboard!')),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Copy IP'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.playerX),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Waiting for opponent on LAN...',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGame(LanRoom room) {
    final gameState = widget.plugin.deserializeState(room.stateData);
    final gameOver = widget.plugin.checkGameOver(gameState);

    final mySymbol = widget.isHost ? 'X' : 'O';
    final opponentSymbol = widget.isHost ? 'O' : 'X';

    dynamic currentTurn;
    try {
      currentTurn = (gameState as dynamic).currentTurn as String?;
    } catch (_) {}
    final isMyTurn = (currentTurn == mySymbol) && !gameOver.isOver;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _confirmLeave,
          ),
          title: Text(
            widget.plugin.displayName,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accentGreen.withAlpha(120)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_rounded, size: 14, color: AppColors.accentGreen),
                  SizedBox(width: 4),
                  Text('LAN', style: TextStyle(fontSize: 11, color: AppColors.accentGreen, fontWeight: FontWeight.w700)),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    TurnIndicator(
                      player1Name: room.hostDisplayName,
                      player2Name: room.guestDisplayName ?? 'Opponent',
                      player1Symbol: 'X',
                      player2Symbol: 'O',
                      isPlayer1Turn: currentTurn == 'X',
                      player1Score: 0,
                      player2Score: 0,
                    ),
                    const SizedBox(height: 12),

                    // Status banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isMyTurn
                            ? AppColors.playerX.withAlpha(30)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isMyTurn ? AppColors.playerX : AppColors.cardBorder,
                        ),
                      ),
                      child: Text(
                        gameOver.isOver
                            ? (gameOver.isDraw
                                ? 'Draw Game!'
                                : gameOver.winner == mySymbol ? 'You win!' : 'Opponent wins!')
                            : (isMyTurn ? 'YOUR TURN ($mySymbol)' : 'OPPONENT\'S TURN ($opponentSymbol)'),
                        style: TextStyle(
                          color: isMyTurn ? AppColors.playerX : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Expanded(
                      child: Center(
                        child: widget.plugin.buildBoardWidget(
                          context: context,
                          state: gameState,
                          onMove: _onMove,
                          isInteractive: isMyTurn && !gameOver.isOver && !_isSubmitting,
                          currentTurnPlayerId: currentTurn?.toString() ?? 'X',
                          localPlayerId: widget.localUid,
                          gameOverResult: gameOver.isOver ? gameOver : null,
                        ),
                      ),
                    ),

                    if (gameOver.isOver)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Back to Lobby'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
