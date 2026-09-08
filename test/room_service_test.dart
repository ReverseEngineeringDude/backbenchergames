import 'package:flutter_test/flutter_test.dart';
import 'package:backbenchgames/core/models/move_record.dart';
import 'package:backbenchgames/core/models/room.dart';
import 'package:backbenchgames/core/models/user_profile.dart';
import 'package:backbenchgames/core/plugin/game_registry.dart';
import 'package:backbenchgames/core/rooms/room_service.dart';
import 'package:backbenchgames/games/tic_tac_toe/tic_tac_toe_plugin.dart';

void main() {
  final roomService = RoomService();

  setUpAll(() {
    GameRegistry().register(TicTacToePlugin());
  });

  setUp(() {
    RoomService.resetForTesting();
  });

  tearDown(() {
    RoomService.resetForTesting();
  });

  final hostUser = UserProfile(
    uid: 'host_123',
    email: 'host@example.com',
    displayName: 'Host Player',
    avatarUrl: 'https://example.com/host.png',
    isAnonymous: false,
    createdAt: DateTime.now(),
  );

  final guestUser = UserProfile(
    uid: 'guest_456',
    email: 'guest@example.com',
    displayName: 'Guest Player',
    avatarUrl: 'https://example.com/guest.png',
    isAnonymous: false,
    createdAt: DateTime.now(),
  );

  group('RoomService Lifecycle and Management', () {
    test('creates a room in waiting status with host player and unique code', () async {
      final room = await roomService.createRoom(
        gameId: 'tic_tac_toe',
        host: hostUser,
      );

      expect(room.id, isNotEmpty);
      expect(room.roomCode, equals(room.id));
      expect(room.status, equals(RoomStatus.waiting));
      expect(room.players.length, equals(1));
      expect(room.players.first.uid, equals(hostUser.uid));
      expect(room.players.first.isHost, isTrue);
      expect(room.players.first.symbol, equals('X'));
      expect(room.isFull, isFalse);
    });

    test('guest successfully joins waiting room and status becomes active', () async {
      final room = await roomService.createRoom(
        gameId: 'tic_tac_toe',
        host: hostUser,
      );

      final joinedRoom = await roomService.joinRoom(
        roomCode: room.roomCode,
        guest: guestUser,
      );

      expect(joinedRoom.status, equals(RoomStatus.active));
      expect(joinedRoom.players.length, equals(2));
      expect(joinedRoom.isFull, isTrue);
      expect(joinedRoom.guestPlayer?.uid, equals(guestUser.uid));
      expect(joinedRoom.guestPlayer?.symbol, equals('O'));
    });

    test('cannot join non-existent room', () async {
      expect(
        () => roomService.joinRoom(roomCode: 'NONEXIST', guest: guestUser),
        throwsA(isA<Exception>()),
      );
    });

    test('cannot join full room', () async {
      final room = await roomService.createRoom(
        gameId: 'tic_tac_toe',
        host: hostUser,
      );

      await roomService.joinRoom(
        roomCode: room.roomCode,
        guest: guestUser,
      );

      final thirdUser = UserProfile(
        uid: 'user_789',
        email: 'third@example.com',
        displayName: 'Third Player',
        createdAt: DateTime.now(),
      );

      expect(
        () => roomService.joinRoom(roomCode: room.roomCode, guest: thirdUser),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Room Dismantling on Leave or Disconnect', () {
    test('dismantleRoom transitions room status to dismantled with reason and author', () async {
      final room = await roomService.createRoom(
        gameId: 'tic_tac_toe',
        host: hostUser,
      );

      await roomService.joinRoom(
        roomCode: room.roomCode,
        guest: guestUser,
      );

      await roomService.dismantleRoom(
        roomId: room.id,
        leaverUid: guestUser.uid,
        reason: '${guestUser.displayName} left the match.',
      );

      final streamRoom = await roomService.listenToRoom(room.id).first;
      expect(streamRoom?.status, equals(RoomStatus.dismantled));
      expect(streamRoom?.isDismantled, isTrue);
      expect(streamRoom?.isFinishedOrDismantled, isTrue);
      expect(streamRoom?.dismantledBy, equals(guestUser.uid));
      expect(streamRoom?.dismantledReason, contains('left the match'));
    });

    test('leaveRoom dismantles the room', () async {
      final room = await roomService.createRoom(
        gameId: 'tic_tac_toe',
        host: hostUser,
      );

      await roomService.leaveRoom(
        roomId: room.id,
        uid: hostUser.uid,
        reason: 'Host left the room',
      );

      final streamRoom = await roomService.listenToRoom(room.id).first;
      expect(streamRoom?.status, equals(RoomStatus.dismantled));
      expect(streamRoom?.dismantledBy, equals(hostUser.uid));
    });

    test('joining a dismantled room throws an exception', () async {
      final room = await roomService.createRoom(
        gameId: 'tic_tac_toe',
        host: hostUser,
      );

      await roomService.dismantleRoom(
        roomId: room.id,
        leaverUid: hostUser.uid,
        reason: 'Room was closed',
      );

      expect(
        () => roomService.joinRoom(roomCode: room.roomCode, guest: guestUser),
        throwsA(
          predicate((e) => e.toString().contains('dismantled and is closed')),
        ),
      );
    });

    test('makeMove on dismantled room is rejected and does not update state', () async {
      final room = await roomService.createRoom(
        gameId: 'tic_tac_toe',
        host: hostUser,
      );

      await roomService.joinRoom(
        roomCode: room.roomCode,
        guest: guestUser,
      );

      await roomService.dismantleRoom(
        roomId: room.id,
        leaverUid: hostUser.uid,
        reason: 'Opponent disconnected',
      );

      final move = MoveRecord(
        sequenceIndex: 0,
        playerId: guestUser.uid,
        moveData: {'index': 4, 'player': 'X'},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await roomService.makeMove(
        roomId: room.id,
        move: move,
        nextState: {'board': List.filled(9, null), 'currentTurn': 'O'},
        nextTurn: 'O',
      );

      final current = await roomService.listenToRoom(room.id).first;
      expect(current?.status, equals(RoomStatus.dismantled));
      expect(current?.moves, isEmpty);
    });

    test('updatePresence updates lastSeen timestamp', () async {
      final room = await roomService.createRoom(
        gameId: 'tic_tac_toe',
        host: hostUser,
      );

      final initialLastSeen = room.players.first.lastSeen;

      await Future.delayed(const Duration(milliseconds: 15));

      await roomService.updatePresence(roomId: room.id, uid: hostUser.uid);

      final updatedRoom = await roomService.listenToRoom(room.id).first;
      expect(updatedRoom?.players.first.lastSeen, greaterThan(initialLastSeen));
    });
  });
}
