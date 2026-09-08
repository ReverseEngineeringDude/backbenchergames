import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/auth/auth_service.dart';
import '../../core/leaderboard/leaderboard_service.dart';
import '../../core/models/game_over_result.dart';
import '../../core/models/game_session.dart';
import '../../core/models/move_record.dart';
import '../../core/models/room.dart';
import '../../core/models/user_profile.dart';
import '../../core/plugin/game_plugin.dart';
import '../../core/replay/session_history_store.dart';
import '../../core/rooms/room_service.dart';
import '../theme/app_colors.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/turn_indicator.dart';
import 'replay_screen.dart';

/// Real-time online multiplayer room screen with presence and state sync.
class OnlineRoomScreen extends StatefulWidget {
  final String roomId;
  final GamePlugin plugin;
  final UserProfile currentUser;

  const OnlineRoomScreen({
    super.key,
    required this.roomId,
    required this.plugin,
    required this.currentUser,
  });

  @override
  State<OnlineRoomScreen> createState() => _OnlineRoomScreenState();
}

class _OnlineRoomScreenState extends State<OnlineRoomScreen>
    with WidgetsBindingObserver {
  final RoomService _roomService = RoomService();
  Timer? _heartbeatTimer;
  Timer? _disconnectMonitorTimer;
  Room? _latestRoom;
  bool _hasRecordedStats = false;
  bool _hasDismantled = false;
  bool _hasShownDismantledDialog = false;
  bool _isSubmittingMove = false;
  bool _isExplicitlyLeaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPresenceHeartbeat();
    _startDisconnectMonitor();
  }

  void _startPresenceHeartbeat() {
    // Ping presence immediately on entry
    _roomService.updatePresence(
      roomId: widget.roomId,
      uid: widget.currentUser.uid,
    );
    // Ping presence every 3 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _roomService.updatePresence(
        roomId: widget.roomId,
        uid: widget.currentUser.uid,
      );
    });
  }

  void _startDisconnectMonitor() {
    // Check opponent connection every 3 seconds
    _disconnectMonitorTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkOpponentConnection();
    });
  }

  void _checkOpponentConnection() {
    final room = _latestRoom;
    if (room == null ||
        room.isFinishedOrDismantled ||
        _hasDismantled ||
        _isExplicitlyLeaving) {
      return;
    }

    final opponent = room.players.cast<RoomPlayer?>().firstWhere(
          (p) => p?.uid != widget.currentUser.uid,
          orElse: () => null,
        );

    // If opponent has joined and heartbeat has lapsed for > 12 seconds
    if (opponent != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - opponent.lastSeen;
      if (elapsed > 12000) {
        _hasDismantled = true;
        _roomService.dismantleRoom(
          roomId: room.id,
          leaverUid: opponent.uid,
          reason: '${opponent.displayName} lost connection.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      if (!_hasDismantled &&
          !_isExplicitlyLeaving &&
          _latestRoom != null &&
          !_latestRoom!.isFinishedOrDismantled) {
        _hasDismantled = true;
        _roomService.dismantleRoom(
          roomId: widget.roomId,
          leaverUid: widget.currentUser.uid,
          reason: '${widget.currentUser.displayName} disconnected.',
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _disconnectMonitorTimer?.cancel();
    if (!_hasDismantled &&
        !_isExplicitlyLeaving &&
        _latestRoom != null &&
        !_latestRoom!.isFinishedOrDismantled) {
      _hasDismantled = true;
      _roomService.dismantleRoom(
        roomId: widget.roomId,
        leaverUid: widget.currentUser.uid,
        reason: '${widget.currentUser.displayName} left the room.',
      );
    }
    super.dispose();
  }

  void _onMove(Room room, dynamic move, String mySymbol) async {
    if (_isSubmittingMove) return;
    if (room.status != RoomStatus.active) return;
    if (room.currentTurn != mySymbol) return;

    final currentState = widget.plugin.deserializeState(room.stateData);
    if (!widget.plugin.isValidMove(currentState, move)) return;

    _isSubmittingMove = true;
    try {
      final nextState = widget.plugin.applyMove(currentState, move);
      final gameOver = widget.plugin.checkGameOver(nextState);

      final nextTurn = room.currentTurn == 'X' ? 'O' : 'X';
      final moveRecord = MoveRecord(
        moveData: widget.plugin.serializeMove(move),
        playerId: widget.currentUser.uid,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        sequenceIndex: room.moves.length,
      );

      String? winnerUid;
      if (gameOver.isOver && !gameOver.isDraw && gameOver.winner != null) {
        final winningPlayer = room.players.cast<RoomPlayer?>().firstWhere(
              (p) => p?.symbol == gameOver.winner,
              orElse: () => null,
            );
        winnerUid = winningPlayer?.uid;
      }

      await _roomService.makeMove(
        roomId: room.id,
        move: moveRecord,
        nextState: widget.plugin.serializeState(nextState),
        nextTurn: nextTurn,
        gameOverResult: gameOver.isOver ? gameOver : null,
        winnerUid: winnerUid,
      );
    } catch (e) {
      debugPrint('Error making move: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit move: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingMove = false;
        });
      } else {
        _isSubmittingMove = false;
      }
    }
  }

  void _onGameFinished(Room room) {
    if (_hasRecordedStats) return;
    _hasRecordedStats = true;

    final myUid = widget.currentUser.uid;
    final isWin = room.winnerUid == myUid;
    final isLoss = room.winnerUid != null && room.winnerUid != myUid;
    final isDraw = room.isDraw;

    AuthService().recordGameResult(
      gameId: widget.plugin.id,
      isWin: isWin,
      isLoss: isLoss,
      isDraw: isDraw,
    );

    final user = AuthService().currentUser;
    if (user != null) {
      final stats = user.statsForGame(widget.plugin.id);
      LeaderboardService().recordScore(
        gameId: widget.plugin.id,
        uid: user.uid,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        wins: stats.wins,
        losses: stats.losses,
        draws: stats.draws,
        rankScore: stats.rankScore,
        currentStreak: stats.currentStreak,
        isAnonymous: user.isAnonymous,
      );
    }

    final host = room.hostPlayer;
    final guest = room.guestPlayer;
    final p1 = host?.displayName ??
        (room.players.isNotEmpty ? room.players.first.displayName : 'Player 1');
    final p2 = guest?.displayName ??
        (room.players.length > 1 ? room.players[1].displayName : 'Player 2');

    String? variantId;
    if (room.stateData['gridSize'] != null) {
      variantId = '${room.stateData['gridSize']}x${room.stateData['gridSize']}';
    }

    final session = GameSession(
      sessionId: 'online_${room.id}_${DateTime.now().millisecondsSinceEpoch}',
      gameId: widget.plugin.id,
      variantId: variantId,
      mode: GamePlayMode.online,
      player1Name: p1,
      player2Name: p2,
      player1Id: host?.uid ?? (room.players.isNotEmpty ? room.players.first.uid : 'p1'),
      player2Id: guest?.uid ?? (room.players.length > 1 ? room.players[1].uid : 'p2'),
      moves: room.moves,
      finalResult: room.status == RoomStatus.forfeited
          ? GameOverResult.win(room.winnerUid ?? 'p1')
          : (room.isDraw
              ? GameOverResult.draw
              : (room.winnerUid != null
                  ? GameOverResult.win(
                      room.players.firstWhere((p) => p.uid == room.winnerUid).symbol)
                  : null)),
      createdAt: room.createdAt,
    );
    SessionHistoryStore().recordSession(session);
  }

  void _showDismantledDialogOnce(Room room) {
    if (_hasShownDismantledDialog || _isExplicitlyLeaving || !mounted) return;
    _hasShownDismantledDialog = true;
    _heartbeatTimer?.cancel();
    _disconnectMonitorTimer?.cancel();

    final reason = room.dismantledReason ??
        'A player left or lost connection. The room has been dismantled.';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.link_off_rounded, color: Colors.amberAccent, size: 28),
            SizedBox(width: 10),
            Text('Room Dismantled',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          reason,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 14, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.playerX,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Back to Lobby',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveRoom(Room room) {
    if (room.isFinishedOrDismantled) {
      Navigator.of(context).pop();
      return;
    }

    final isMatchActive = room.status == RoomStatus.active;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('Leave Room?'),
          ],
        ),
        content: Text(
          isMatchActive
              ? 'Leaving will dismantle the room and end the match for both players.'
              : 'Leaving will close and dismantle this room.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              _isExplicitlyLeaving = true;
              _hasDismantled = true;
              _heartbeatTimer?.cancel();
              _disconnectMonitorTimer?.cancel();
              Navigator.of(ctx).pop();

              await _roomService.dismantleRoom(
                roomId: room.id,
                leaverUid: widget.currentUser.uid,
                reason: '${widget.currentUser.displayName} left the room.',
              );

              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Leave & Dismantle'),
          ),
        ],
      ),
    );
  }

  Widget _buildDismantledView(Room room) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Room Dismantled'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.link_off_rounded,
                    size: 64, color: Colors.amberAccent),
                const SizedBox(height: 16),
                const Text(
                  'Match Ended',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  room.dismantledReason ??
                      'A player left or lost connection. The room has been dismantled.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.playerX,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Back to Lobby',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Room?>(
      stream: _roomService.listenToRoom(widget.roomId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.playerX),
            ),
          );
        }

        final room = snapshot.data;
        if (room == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Room Not Found')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  const Text('Room not found or has expired.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to Lobby'),
                  ),
                ],
              ),
            ),
          );
        }

        _latestRoom = room;

        if (room.status == RoomStatus.dismantled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showDismantledDialogOnce(room);
          });
          return _buildDismantledView(room);
        }

        if (room.status == RoomStatus.finished ||
            room.status == RoomStatus.forfeited) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onGameFinished(room);
          });
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _confirmLeaveRoom(room);
          },
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => _confirmLeaveRoom(room),
              ),
              title: Hero(
                tag: 'room_header_${room.id}',
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    'Room #${room.roomCode}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  tooltip: 'Copy Room Code',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: room.roomCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Room code ${room.roomCode} copied!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  tooltip: 'Leave Room',
                  onPressed: () => _confirmLeaveRoom(room),
                ),
              ],
            ),
            body: SafeArea(
              child: room.status == RoomStatus.waiting
                  ? _buildWaitingLobby(room)
                  : _buildActiveGame(room),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaitingLobby(Room room) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glowing Room Code Container
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.playerX, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.playerXGlow,
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'SHARE ROOM CODE',
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
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.playerX,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: room.roomCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Room code ${room.roomCode} copied!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Code'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Players in lobby
              Row(
                children: [
                  Expanded(
                    child: _buildLobbyPlayerSlot(
                      player: room.hostPlayer,
                      isHost: true,
                      symbol: 'X',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildLobbyPlayerSlot(
                      player: room.guestPlayer,
                      isHost: false,
                      symbol: 'O',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Waiting spinner
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.playerX,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Waiting for opponent to join...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLobbyPlayerSlot({
    required RoomPlayer? player,
    required bool isHost,
    required String symbol,
  }) {
    final color = symbol == 'X' ? AppColors.playerX : AppColors.playerO;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: player != null ? color : AppColors.cardBorder,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          AvatarWidget(
            displayName: player?.displayName ?? '?',
            size: 50,
            borderColor: color,
          ),
          const SizedBox(height: 8),
          Text(
            player?.displayName ?? 'Waiting...',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: player != null ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isHost ? 'Host ($symbol)' : 'Guest ($symbol)',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveGame(Room room) {
    final gameState = widget.plugin.deserializeState(room.stateData);
    final gameOver = widget.plugin.checkGameOver(gameState);
    final isGameOver = room.status == RoomStatus.finished ||
        room.status == RoomStatus.forfeited ||
        gameOver.isOver;

    final myPlayer = room.playerByUid(widget.currentUser.uid);
    final mySymbol = myPlayer?.symbol ?? 'X';
    final isMyTurn = room.currentTurn == mySymbol && !isGameOver;

    final host = room.hostPlayer;
    final guest = room.guestPlayer;
    final p1 = host ?? (room.players.isNotEmpty ? room.players.first : null);
    final p2 = guest ?? (room.players.length > 1 ? room.players[1] : null);

    final opponent = room.players.cast<RoomPlayer?>().firstWhere(
          (p) => p?.uid != widget.currentUser.uid,
          orElse: () => null,
        );
    final isOpponentLagging = opponent != null &&
        !isGameOver &&
        (DateTime.now().millisecondsSinceEpoch - opponent.lastSeen > 6000);

    String statusText;
    Color statusColor;
    if (isGameOver) {
      statusText = room.status == RoomStatus.forfeited
          ? 'Match Ended (Forfeit)'
          : 'Game Over';
      statusColor = AppColors.textSecondary;
    } else if (isOpponentLagging) {
      statusText = 'Opponent connection unstable...';
      statusColor = Colors.amberAccent;
    } else if (isMyTurn) {
      statusText = 'YOUR TURN ($mySymbol)';
      statusColor = AppColors.playerX;
    } else {
      statusText = "OPPONENT'S TURN";
      statusColor = AppColors.textSecondary;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // Turn Indicator
              TurnIndicator(
                player1Name: p1?.displayName ?? 'Player 1',
                player2Name: p2?.displayName ?? 'Player 2',
                player1Symbol: p1?.symbol ?? 'X',
                player2Symbol: p2?.symbol ?? 'O',
                isPlayer1Turn: room.currentTurn == (p1?.symbol ?? 'X'),
                player1Score: room.winnerUid == p1?.uid ? 1 : 0,
                player2Score: room.winnerUid == p2?.uid ? 1 : 0,
              ),
              const SizedBox(height: 16),

              // Status banner (e.g. Your Turn / Opponent Thinking)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isMyTurn
                      ? AppColors.playerX.withAlpha(30)
                      : (isOpponentLagging
                          ? Colors.amberAccent.withAlpha(30)
                          : AppColors.surfaceLight),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isMyTurn
                        ? AppColors.playerX
                        : (isOpponentLagging
                            ? Colors.amberAccent
                            : AppColors.cardBorder),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isOpponentLagging) ...[
                      const Icon(Icons.wifi_tethering_error_rounded,
                          size: 16, color: Colors.amberAccent),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Game Board
              Expanded(
                child: Center(
                  child: widget.plugin.buildBoardWidget(
                    context: context,
                    state: gameState,
                    onMove: (move) => _onMove(room, move, mySymbol),
                    isInteractive: isMyTurn && !isGameOver && !_isSubmittingMove,
                    currentTurnPlayerId: room.currentTurn,
                    localPlayerId: widget.currentUser.uid,
                    gameOverResult: gameOver.isOver ? gameOver : null,
                  ),
                ),
              ),

              // Post-game or Active controls
              if (isGameOver)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            String? variantId;
                            if (room.stateData['gridSize'] != null) {
                              variantId = '${room.stateData['gridSize']}x${room.stateData['gridSize']}';
                            }

                            final session = GameSession(
                              sessionId:
                                  'online_${room.id}_${DateTime.now().millisecondsSinceEpoch}',
                              gameId: widget.plugin.id,
                              variantId: variantId,
                              mode: GamePlayMode.online,
                              player1Name: p1?.displayName ?? 'Player 1',
                              player2Name: p2?.displayName ?? 'Player 2',
                              player1Id: p1?.uid ?? 'p1',
                              player2Id: p2?.uid ?? 'p2',
                              moves: room.moves,
                              finalResult: gameOver,
                              createdAt: room.createdAt,
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
                          icon: const Icon(Icons.history_rounded),
                          label: const Text('Replay Match'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back to Lobby'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
