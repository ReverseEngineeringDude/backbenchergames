import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:backbenchgames/core/auth/auth_service.dart';
import 'package:backbenchgames/core/leaderboard/leaderboard_service.dart';
import 'package:backbenchgames/core/models/ai_difficulty.dart';
import 'package:backbenchgames/core/models/game_session.dart';
import 'package:backbenchgames/core/models/move_record.dart';
import 'package:backbenchgames/core/replay/replay_controller.dart';
import 'package:backbenchgames/games/tic_tac_toe/logic.dart';
import 'package:backbenchgames/games/tic_tac_toe/ai.dart';
import 'package:backbenchgames/games/tic_tac_toe/tic_tac_toe_plugin.dart';

void main() {
  group('TicTacToeLogic', () {
    test('initial state has empty board and turn X', () {
      final state = TicTacToeLogic.initialState();
      expect(state.board.length, equals(9));
      expect(state.board.every((cell) => cell == null), isTrue);
      expect(state.currentTurn, equals('X'));
      expect(state.moveCount, equals(0));
      expect(state.lastMoveIndex, isNull);
    });

    test('valid move updates board, switches turn and increments moveCount', () {
      final state = TicTacToeLogic.initialState();
      const move = TicTacToeMove(index: 4, player: 'X');
      expect(TicTacToeLogic.isValidMove(state, move), isTrue);

      final nextState = TicTacToeLogic.applyMove(state, move);
      expect(nextState.board[4], equals('X'));
      expect(nextState.currentTurn, equals('O'));
      expect(nextState.moveCount, equals(1));
      expect(nextState.lastMoveIndex, equals(4));
    });

    test('invalid moves are rejected', () {
      final state = TicTacToeLogic.initialState();

      // Wrong turn
      expect(
        TicTacToeLogic.isValidMove(state, const TicTacToeMove(index: 0, player: 'O')),
        isFalse,
      );

      // Out of bounds
      expect(
        TicTacToeLogic.isValidMove(state, const TicTacToeMove(index: -1, player: 'X')),
        isFalse,
      );
      expect(
        TicTacToeLogic.isValidMove(state, const TicTacToeMove(index: 9, player: 'X')),
        isFalse,
      );

      // Already occupied
      final state1 = TicTacToeLogic.applyMove(
        state,
        const TicTacToeMove(index: 0, player: 'X'),
      );
      expect(
        TicTacToeLogic.isValidMove(state1, const TicTacToeMove(index: 0, player: 'O')),
        isFalse,
      );
    });

    test('detects horizontal win with winningIndices', () {
      // Row 0: [0, 1, 2]
      var state = TicTacToeLogic.initialState();
      state = TicTacToeLogic.applyMove(state, const TicTacToeMove(index: 0, player: 'X'));
      state = TicTacToeLogic.applyMove(state, const TicTacToeMove(index: 3, player: 'O'));
      state = TicTacToeLogic.applyMove(state, const TicTacToeMove(index: 1, player: 'X'));
      state = TicTacToeLogic.applyMove(state, const TicTacToeMove(index: 4, player: 'O'));
      state = TicTacToeLogic.applyMove(state, const TicTacToeMove(index: 2, player: 'X'));

      final result = TicTacToeLogic.checkGameOver(state);
      expect(result.isOver, isTrue);
      expect(result.isDraw, isFalse);
      expect(result.winner, equals('X'));
      expect(result.winningIndices, equals([0, 1, 2]));
    });

    test('detects vertical win with winningIndices', () {
      // Col 1: [1, 4, 7]
      var state = TicTacToeLogic.initialState();
      state = TicTacToeLogic.applyMove(state, const TicTacToeMove(index: 0, player: 'X'));
      state = TicTacToeLogic.applyMove(state, const TicTacToeMove(index: 1, player: 'O'));
      state = TicTacToeLogic.applyMove(state, const TicTacToeMove(index: 3, player: 'X'));
      state = TicTacToeLogic.applyMove(state, const TicTacToeMove(index: 4, player: 'O'));
      state = TicTacToeLogic.applyMove(state, const TicTacToeMove(index: 8, player: 'X'));
      state = TicTacToeLogic.applyMove(state, const TicTacToeMove(index: 7, player: 'O'));

      final result = TicTacToeLogic.checkGameOver(state);
      expect(result.isOver, isTrue);
      expect(result.isDraw, isFalse);
      expect(result.winner, equals('O'));
      expect(result.winningIndices, equals([1, 4, 7]));
    });

    test('detects diagonal win with winningIndices', () {
      // Diagonal: [2, 4, 6]
      var state = TicTacToeLogic.initialState();
      state = TicTacToeLogic.applyMove(state, const TicTacToeMove(index: 2, player: 'X'));
      state = TicTacToeLogic.applyMove(state, const TicTacToeMove(index: 0, player: 'O'));
      state = TicTacToeLogic.applyMove(state, const TicTacToeMove(index: 4, player: 'X'));
      state = TicTacToeLogic.applyMove(state, const TicTacToeMove(index: 1, player: 'O'));
      state = TicTacToeLogic.applyMove(state, const TicTacToeMove(index: 6, player: 'X'));

      final result = TicTacToeLogic.checkGameOver(state);
      expect(result.isOver, isTrue);
      expect(result.isDraw, isFalse);
      expect(result.winner, equals('X'));
      expect(result.winningIndices, equals([2, 4, 6]));
    });

    test('detects draw when full without winner', () {
      // Board:
      // X O X
      // X X O
      // O X O
      var state = TicTacToeLogic.initialState();
      final moves = [
        const TicTacToeMove(index: 0, player: 'X'),
        const TicTacToeMove(index: 1, player: 'O'),
        const TicTacToeMove(index: 2, player: 'X'),
        const TicTacToeMove(index: 5, player: 'O'),
        const TicTacToeMove(index: 3, player: 'X'),
        const TicTacToeMove(index: 6, player: 'O'),
        const TicTacToeMove(index: 4, player: 'X'),
        const TicTacToeMove(index: 8, player: 'O'),
        const TicTacToeMove(index: 7, player: 'X'),
      ];

      for (final move in moves) {
        state = TicTacToeLogic.applyMove(state, move);
      }

      final result = TicTacToeLogic.checkGameOver(state);
      expect(result.isOver, isTrue);
      expect(result.isDraw, isTrue);
      expect(result.winner, isNull);
    });

    test('serialization round-trip preserves state and move', () {
      final state = TicTacToeState(
        board: ['X', null, 'O', null, 'X', null, null, null, 'O'],
        currentTurn: 'X',
        moveCount: 4,
        lastMoveIndex: 8,
      );

      final json = state.toJson();
      final deserialized = TicTacToeState.fromJson(json);
      expect(deserialized, equals(state));

      const move = TicTacToeMove(index: 5, player: 'X');
      final moveJson = move.toJson();
      final deserializedMove = TicTacToeMove.fromJson(moveJson);
      expect(deserializedMove, equals(move));
    });
  });

  group('TicTacToeAI', () {
    final ai = TicTacToeAI(Random(42));

    test('Impossible AI seizes immediate win', () {
      // Board:
      // X X .
      // O O .
      // . . .
      // Turn: X -> AI must choose 2 to win immediately
      final state = TicTacToeState(
        board: ['X', 'X', null, 'O', 'O', null, null, null, null],
        currentTurn: 'X',
        moveCount: 4,
      );

      final move = ai.getNextMove(state, AIDifficulty.impossible);
      expect(move, isNotNull);
      expect(move!.index, equals(2));
      expect(move.player, equals('X'));
    });

    test('Impossible AI blocks opponent immediate win', () {
      // Board:
      // O O .
      // X . .
      // . . .
      // Turn: X -> AI must choose 2 to block O
      final state = TicTacToeState(
        board: ['O', 'O', null, 'X', null, null, null, null, null],
        currentTurn: 'X',
        moveCount: 3,
      );

      final move = ai.getNextMove(state, AIDifficulty.impossible);
      expect(move, isNotNull);
      expect(move!.index, equals(2));
      expect(move.player, equals('X'));
    });

    test('Impossible AI vs Impossible AI always results in a draw', () {
      var state = TicTacToeLogic.initialState();
      while (!TicTacToeLogic.checkGameOver(state).isOver) {
        final move = ai.getNextMove(state, AIDifficulty.impossible);
        expect(move, isNotNull);
        state = TicTacToeLogic.applyMove(state, move!);
      }

      final result = TicTacToeLogic.checkGameOver(state);
      expect(result.isOver, isTrue);
      expect(result.isDraw, isTrue);
      expect(result.winner, isNull);
    });

    test('Impossible AI never loses against random moves in 50 simulations', () {
      final random = Random(12345);
      final testAi = TicTacToeAI(random);

      for (int i = 0; i < 50; i++) {
        var state = TicTacToeLogic.initialState();
        final aiIsX = i % 2 == 0;

        while (!TicTacToeLogic.checkGameOver(state).isOver) {
          final isAiTurn = (state.currentTurn == 'X') == aiIsX;

          if (isAiTurn) {
            final move = testAi.getNextMove(state, AIDifficulty.impossible)!;
            state = TicTacToeLogic.applyMove(state, move);
          } else {
            // Opponent makes random legal move
            final available = TicTacToeLogic.getAvailableMoves(state);
            final pick = available[random.nextInt(available.length)];
            state = TicTacToeLogic.applyMove(
              state,
              TicTacToeMove(index: pick, player: state.currentTurn),
            );
          }
        }

        final result = TicTacToeLogic.checkGameOver(state);
        final opponentSymbol = aiIsX ? 'O' : 'X';

        expect(
          result.winner != opponentSymbol,
          isTrue,
          reason: 'Game $i: Impossible AI should NEVER lose to random opponent! Winner: ${result.winner}',
        );
      }
    });

    test('Easy AI produces valid moves', () {
      final state = TicTacToeLogic.initialState();
      final move = ai.getNextMove(state, AIDifficulty.easy);
      expect(move, isNotNull);
      expect(TicTacToeLogic.isValidMove(state, move!), isTrue);
    });

    test('Medium AI produces valid moves', () {
      final state = TicTacToeLogic.initialState();
      final move = ai.getNextMove(state, AIDifficulty.medium);
      expect(move, isNotNull);
      expect(TicTacToeLogic.isValidMove(state, move!), isTrue);
    });
  });

  group('TicTacToe Multi-Grid Logic (6x6 and 9x9)', () {
    test('6x6 grid requires 4 dots to win', () {
      final state = TicTacToeLogic.initialState(gridSize: 6);
      expect(state.gridSize, equals(6));
      expect(state.winLength, equals(4));
      expect(state.totalCells, equals(36));

      // Place 3 X's in a row -> should NOT win
      final board3 = List<String?>.filled(36, null);
      board3[0] = 'X';
      board3[1] = 'X';
      board3[2] = 'X';
      final state3 = state.copyWith(board: board3);
      expect(TicTacToeLogic.checkGameOver(state3).isOver, isFalse);

      // Place 4th X in the row -> should win with [0, 1, 2, 3]
      final board4 = List<String?>.from(board3);
      board4[3] = 'X';
      final state4 = state.copyWith(board: board4);
      final result = TicTacToeLogic.checkGameOver(state4);
      expect(result.isOver, isTrue);
      expect(result.winner, equals('X'));
      expect(result.winningIndices, equals([0, 1, 2, 3]));
    });

    test('6x6 diagonal win requires 4 dots', () {
      final state = TicTacToeLogic.initialState(gridSize: 6);
      // Diagonal down-right: (1,1)=7, (2,2)=14, (3,3)=21, (4,4)=28
      final board = List<String?>.filled(36, null);
      board[7] = 'O';
      board[14] = 'O';
      board[21] = 'O';
      board[28] = 'O';

      final diagState = state.copyWith(board: board);
      final result = TicTacToeLogic.checkGameOver(diagState);
      expect(result.isOver, isTrue);
      expect(result.winner, equals('O'));
      expect(result.winningIndices, equals([7, 14, 21, 28]));
    });

    test('9x9 grid requires 5 dots to win', () {
      final state = TicTacToeLogic.initialState(gridSize: 9);
      expect(state.gridSize, equals(9));
      expect(state.winLength, equals(5));
      expect(state.totalCells, equals(81));

      // Place 4 X's in a row -> should NOT win
      final board4 = List<String?>.filled(81, null);
      for (int i = 0; i < 4; i++) {
        board4[10 + i] = 'X'; // Row 1, cols 1..4
      }
      final state4 = state.copyWith(board: board4);
      expect(TicTacToeLogic.checkGameOver(state4).isOver, isFalse);

      // Place 5th X in the row -> should win with [10, 11, 12, 13, 14]
      final board5 = List<String?>.from(board4);
      board5[14] = 'X';
      final state5 = state.copyWith(board: board5);
      final result = TicTacToeLogic.checkGameOver(state5);
      expect(result.isOver, isTrue);
      expect(result.winner, equals('X'));
      expect(result.winningIndices, equals([10, 11, 12, 13, 14]));
    });

    test('9x9 diagonal win requires 5 dots', () {
      final state = TicTacToeLogic.initialState(gridSize: 9);
      // Diagonal: (0,0)=0, (1,1)=10, (2,2)=20, (3,3)=30, (4,4)=40
      final board = List<String?>.filled(81, null);
      board[0] = 'X';
      board[10] = 'X';
      board[20] = 'X';
      board[30] = 'X';
      board[40] = 'X';

      final diagState = state.copyWith(board: board);
      final result = TicTacToeLogic.checkGameOver(diagState);
      expect(result.isOver, isTrue);
      expect(result.winner, equals('X'));
      expect(result.winningIndices, equals([0, 10, 20, 30, 40]));
    });

    test('AI seizes immediate 4-dot win on 6x6', () {
      final ai = TicTacToeAI();
      final board = List<String?>.filled(36, null);
      // Row 2: (2,0)=12, (2,1)=13, (2,2)=14 are X
      board[12] = 'X';
      board[13] = 'X';
      board[14] = 'X';
      // Some dummy moves elsewhere
      board[0] = 'O';
      board[1] = 'O';

      final state = TicTacToeState(
        gridSize: 6,
        winLength: 4,
        board: board,
        currentTurn: 'X',
        moveCount: 5,
      );

      final move = ai.getNextMove(state, AIDifficulty.impossible);
      expect(move, isNotNull);
      // AI must pick either 15 to complete the 4 in a row!
      expect(move!.index, equals(15));
    });

    test('AI blocks opponent 4-dot win on 6x6', () {
      final ai = TicTacToeAI();
      final board = List<String?>.filled(36, null);
      // Opponent O has (0,0)=0, (0,1)=1, (0,2)=2
      board[0] = 'O';
      board[1] = 'O';
      board[2] = 'O';
      // AI is X
      board[18] = 'X';
      board[19] = 'X';

      final state = TicTacToeState(
        gridSize: 6,
        winLength: 4,
        board: board,
        currentTurn: 'X',
        moveCount: 5,
      );

      final move = ai.getNextMove(state, AIDifficulty.impossible);
      expect(move, isNotNull);
      // AI must block at 3!
      expect(move!.index, equals(3));
    });

    test('AI makes fast valid move on 9x9', () {
      final ai = TicTacToeAI();
      final state = TicTacToeLogic.initialState(gridSize: 9);

      final stopwatch = Stopwatch()..start();
      final move = ai.getNextMove(state, AIDifficulty.impossible);
      stopwatch.stop();

      expect(move, isNotNull);
      expect(TicTacToeLogic.isValidMove(state, move!), isTrue);
      // Computation should take < 50ms
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });

  group('Replay and Variant Resolution', () {
    test('ReplayController replays 6x6 game with index 14 when variantId is explicit', () {
      final plugin = TicTacToePlugin();
      final moves = [
        MoveRecord(
          sequenceIndex: 0,
          playerId: 'p1',
          moveData: {'index': 14, 'player': 'X'},
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
        MoveRecord(
          sequenceIndex: 1,
          playerId: 'p2',
          moveData: {'index': 20, 'player': 'O'},
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      ];

      final session = GameSession(
        sessionId: 'test_session',
        gameId: 'tic_tac_toe',
        variantId: '6x6',
        mode: GamePlayMode.local,
        player1Name: 'Player X',
        player2Name: 'Player O',
        player1Id: 'p1',
        player2Id: 'p2',
        moves: moves,
        createdAt: DateTime.now(),
      );

      final controller = ReplayController(session: session, plugin: plugin);
      expect((controller.currentState as TicTacToeState).gridSize, equals(6));

      // Step forward move 0 (X at 14)
      expect(() => controller.stepForward(), returnsNormally);
      expect(controller.currentStepIndex, equals(1));
      final state1 = controller.currentState as TicTacToeState;
      expect(state1.board[14], equals('X'));
      expect(state1.currentTurn, equals('O'));

      // Step forward move 1 (O at 20)
      expect(() => controller.stepForward(), returnsNormally);
      expect(controller.currentStepIndex, equals(2));
      final state2 = controller.currentState as TicTacToeState;
      expect(state2.board[20], equals('O'));
      expect(state2.currentTurn, equals('X'));
    });

    test('ReplayController infers 6x6 variant from move at index 14 when variantId is null', () {
      final plugin = TicTacToePlugin();
      final moves = [
        MoveRecord(
          sequenceIndex: 0,
          playerId: 'p1',
          moveData: {'index': 14, 'player': 'X'},
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      ];

      final session = GameSession(
        sessionId: 'legacy_session',
        gameId: 'tic_tac_toe',
        variantId: null, // Legacy session without variantId
        mode: GamePlayMode.local,
        player1Name: 'Player X',
        player2Name: 'Player O',
        player1Id: 'p1',
        player2Id: 'p2',
        moves: moves,
        createdAt: DateTime.now(),
      );

      final controller = ReplayController(session: session, plugin: plugin);
      expect((controller.currentState as TicTacToeState).gridSize, equals(6));

      // Stepping forward must not throw Invalid argument: TicTacToeMove(X at 14)
      expect(() => controller.stepForward(), returnsNormally);
      expect(controller.currentStepIndex, equals(1));
      final state = controller.currentState as TicTacToeState;
      expect(state.board[14], equals('X'));
    });

    test('ReplayController infers 9x9 variant when max index >= 36', () {
      final plugin = TicTacToePlugin();
      final moves = [
        MoveRecord(
          sequenceIndex: 0,
          playerId: 'p1',
          moveData: {'index': 45, 'player': 'X'},
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      ];

      final session = GameSession(
        sessionId: 'session_9x9',
        gameId: 'tic_tac_toe',
        variantId: null,
        mode: GamePlayMode.local,
        player1Name: 'Player X',
        player2Name: 'Player O',
        player1Id: 'p1',
        player2Id: 'p2',
        moves: moves,
        createdAt: DateTime.now(),
      );

      final controller = ReplayController(session: session, plugin: plugin);
      expect((controller.currentState as TicTacToeState).gridSize, equals(9));
      expect(() => controller.stepForward(), returnsNormally);
    });
  });

  group('Auth and Leaderboard Policy', () {
    test('guest / skipped user (isAnonymous=true) is excluded from leaderboard', () async {
      final leaderboardService = LeaderboardService();
      final guestUid = 'guest_test_${DateTime.now().millisecondsSinceEpoch}';

      await leaderboardService.recordScore(
        gameId: 'tic_tac_toe',
        uid: guestUid,
        displayName: 'Guest Player',
        wins: 10,
        losses: 0,
        draws: 0,
        rankScore: 2500,
        currentStreak: 10,
        isAnonymous: true,
      );

      final entries = await leaderboardService.getLeaderboard('tic_tac_toe');
      final found = entries.any((e) => e.uid == guestUid);
      expect(found, isFalse);
    });

    test('authenticated user (isAnonymous=false) is recorded in leaderboard', () async {
      final leaderboardService = LeaderboardService();
      final userUid = 'google_user_${DateTime.now().millisecondsSinceEpoch}';

      await leaderboardService.recordScore(
        gameId: 'tic_tac_toe',
        uid: userUid,
        displayName: 'Google Player',
        wins: 10,
        losses: 0,
        draws: 0,
        rankScore: 2500,
        currentStreak: 10,
        isAnonymous: false,
      );

      final entries = await leaderboardService.getLeaderboard('tic_tac_toe');
      final found = entries.any((e) => e.uid == userUid);
      expect(found, isTrue);
    });

    test('AuthService.signInAsGuest marks user as anonymous', () async {
      final auth = AuthService();
      final guest = await auth.signInAsGuest('Test Guest');
      expect(guest.isAnonymous, isTrue);
      expect(auth.currentUser?.isAnonymous, isTrue);
    });

    test('AuthService.signInWithGoogle marks user as not anonymous', () async {
      final auth = AuthService();
      final user = await auth.signInWithGoogle();
      expect(user?.isAnonymous, isFalse);
      expect(auth.currentUser?.isAnonymous, isFalse);
    });
  });
}
