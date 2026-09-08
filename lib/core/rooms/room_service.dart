import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/game_over_result.dart';
import '../models/move_record.dart';
import '../models/room.dart';
import '../models/user_profile.dart';
import '../plugin/game_registry.dart';

/// Service managing multiplayer rooms, presence, and real-time state sync.
class RoomService {
  static final RoomService _instance = RoomService._internal();
  factory RoomService() => _instance;
  RoomService._internal();

  bool get _isFirebaseAvailable => Firebase.apps.isNotEmpty;

  // In-memory rooms cache / simulated realtime network for demo & tests
  static final Map<String, Room> _localRooms = {};
  static final Map<String, StreamController<Room>> _localStreams = {};

  /// Generates a random 6-character alphanumeric room code.
  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Avoid O, 0, 1, I confusion
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Creates a new multiplayer room for [gameId].
  Future<Room> createRoom({
    required String gameId,
    required UserProfile host,
    Map<String, dynamic>? customInitialState,
  }) async {
    final gamePlugin = GameRegistry().get(gameId);
    if (gamePlugin == null) {
      throw ArgumentError('Game plugin not found for id: $gameId');
    }

    var roomCode = _generateRoomCode();
    if (_isFirebaseAvailable) {
      final collection = FirebaseFirestore.instance.collection('rooms');
      var doc = await collection.doc(roomCode).get();
      int attempts = 0;
      while (doc.exists && attempts < 5) {
        roomCode = _generateRoomCode();
        doc = await collection.doc(roomCode).get();
        attempts++;
      }
    } else {
      int attempts = 0;
      while (_localRooms.containsKey(roomCode) && attempts < 5) {
        roomCode = _generateRoomCode();
        attempts++;
      }
    }

    final initialState = customInitialState ??
        gamePlugin.serializeState(gamePlugin.initialState());

    final hostPlayer = RoomPlayer(
      uid: host.uid,
      displayName: host.displayName,
      avatarUrl: host.avatarUrl,
      symbol: 'X',
      isHost: true,
      lastSeen: DateTime.now().millisecondsSinceEpoch,
    );

    final now = DateTime.now();
    final room = Room(
      id: roomCode,
      roomCode: roomCode,
      gameId: gameId,
      hostUid: host.uid,
      players: [hostPlayer],
      status: RoomStatus.waiting,
      currentTurn: 'X',
      stateData: initialState,
      moves: const [],
      createdAt: now,
      updatedAt: now,
    );

    if (_isFirebaseAvailable) {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomCode)
          .set(room.toJson());
    } else {
      _localRooms[roomCode] = room;
      final controller = _getOrCreateLocalStream(roomCode);
      if (!controller.isClosed) {
        controller.add(room);
      }
    }

    return room;
  }

  /// Joins an existing room with [roomCode].
  Future<Room> joinRoom({
    required String roomCode,
    required UserProfile guest,
  }) async {
    final cleanCode = roomCode.trim().toUpperCase();

    if (_isFirebaseAvailable) {
      final docRef = FirebaseFirestore.instance.collection('rooms').doc(cleanCode);
      final doc = await docRef.get();

      if (!doc.exists || doc.data() == null) {
        throw Exception('Room code $cleanCode not found');
      }

      final room = Room.fromJson(doc.data()!);
      if (room.status == RoomStatus.dismantled) {
        throw Exception('This room has been dismantled and is closed.');
      }
      if (room.status == RoomStatus.finished || room.status == RoomStatus.forfeited) {
        throw Exception('This match has already ended.');
      }

      if (room.players.any((p) => p.uid == guest.uid)) {
        // Player already in room, rejoin
        return room;
      }

      if (room.status != RoomStatus.waiting || room.isFull) {
        throw Exception('Room is already full or no longer accepting players.');
      }

      // Check if host has abandoned the room (no heartbeat for > 25 seconds)
      final hostPlayer = room.hostPlayer;
      if (hostPlayer != null) {
        final hostAge = DateTime.now().millisecondsSinceEpoch - hostPlayer.lastSeen;
        if (hostAge > 25000) {
          await dismantleRoom(
            roomId: room.id,
            leaverUid: hostPlayer.uid,
            reason: 'Host disconnected or abandoned the room.',
          );
          throw Exception('Host has disconnected or room has expired.');
        }
      }

      final guestPlayer = RoomPlayer(
        uid: guest.uid,
        displayName: guest.displayName,
        avatarUrl: guest.avatarUrl,
        symbol: 'O',
        isHost: false,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      final updatedPlayers = [...room.players, guestPlayer];
      final updatedRoom = room.copyWith(
        players: updatedPlayers,
        status: RoomStatus.active,
        updatedAt: DateTime.now(),
      );

      await docRef.update({
        'players': updatedPlayers.map((p) => p.toJson()).toList(),
        'status': RoomStatus.active.name,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      return updatedRoom;
    } else {
      final room = _localRooms[cleanCode];
      if (room == null) {
        throw Exception('Room code $cleanCode not found');
      }

      if (room.status == RoomStatus.dismantled) {
        throw Exception('This room has been dismantled and is closed.');
      }
      if (room.status == RoomStatus.finished || room.status == RoomStatus.forfeited) {
        throw Exception('This match has already ended.');
      }

      if (room.players.any((p) => p.uid == guest.uid)) {
        return room;
      }

      if (room.status != RoomStatus.waiting || room.isFull) {
        throw Exception('Room is already full or no longer accepting players.');
      }

      final hostPlayer = room.hostPlayer;
      if (hostPlayer != null) {
        final hostAge = DateTime.now().millisecondsSinceEpoch - hostPlayer.lastSeen;
        if (hostAge > 25000) {
          await dismantleRoom(
            roomId: room.id,
            leaverUid: hostPlayer.uid,
            reason: 'Host disconnected or abandoned the room.',
          );
          throw Exception('Host has disconnected or room has expired.');
        }
      }

      final guestPlayer = RoomPlayer(
        uid: guest.uid,
        displayName: guest.displayName,
        avatarUrl: guest.avatarUrl,
        symbol: 'O',
        isHost: false,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      final updatedRoom = room.copyWith(
        players: [...room.players, guestPlayer],
        status: RoomStatus.active,
        updatedAt: DateTime.now(),
      );

      _localRooms[cleanCode] = updatedRoom;
      final controller = _getOrCreateLocalStream(cleanCode);
      if (!controller.isClosed) {
        controller.add(updatedRoom);
      }
      return updatedRoom;
    }
  }

  /// Listens narrowly to a single room document for real-time state sync.
  Stream<Room?> listenToRoom(String roomId) {
    if (_isFirebaseAvailable) {
      return FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        return Room.fromJson(snapshot.data()!);
      });
    } else {
      final streamController = _getOrCreateLocalStream(roomId);
      // Immediately emit current state if available
      final current = _localRooms[roomId];
      if (current != null) {
        Future.microtask(() => streamController.add(current));
      }
      return streamController.stream;
    }
  }

  /// Commits a move to the room and synchronizes with Firestore.
  Future<void> makeMove({
    required String roomId,
    required MoveRecord move,
    required Map<String, dynamic> nextState,
    required String nextTurn,
    GameOverResult? gameOverResult,
    String? winnerUid,
  }) async {
    final isGameOver = gameOverResult?.isOver ?? false;
    final isDraw = gameOverResult?.isDraw ?? false;

    if (_isFirebaseAvailable) {
      final docRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);
      final doc = await docRef.get();
      if (!doc.exists || doc.data() == null) return;
      final currentRoom = Room.fromJson(doc.data()!);
      if (currentRoom.isFinishedOrDismantled) return;

      final updateData = <String, dynamic>{
        'stateData': nextState,
        'currentTurn': nextTurn,
        'moves': FieldValue.arrayUnion([move.toJson()]),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (isGameOver) {
        updateData['status'] = RoomStatus.finished.name;
        updateData['winnerUid'] = winnerUid;
        updateData['isDraw'] = isDraw;
      }

      await docRef.update(updateData);
    } else {
      final room = _localRooms[roomId];
      if (room == null || room.isFinishedOrDismantled) return;

      final updatedMoves = [...room.moves, move];
      final updatedRoom = room.copyWith(
        stateData: nextState,
        currentTurn: nextTurn,
        moves: updatedMoves,
        status: isGameOver ? RoomStatus.finished : room.status,
        winnerUid: winnerUid,
        isDraw: isDraw,
        updatedAt: DateTime.now(),
      );

      _localRooms[roomId] = updatedRoom;
      final controller = _getOrCreateLocalStream(roomId);
      if (!controller.isClosed) {
        controller.add(updatedRoom);
      }
    }
  }

  /// Sends presence heartbeat for [uid] in [roomId].
  Future<void> updatePresence({
    required String roomId,
    required String uid,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (_isFirebaseAvailable) {
      try {
        final docRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);
        final doc = await docRef.get();
        if (!doc.exists || doc.data() == null) return;

        final room = Room.fromJson(doc.data()!);
        if (room.isFinishedOrDismantled) return;

        final updatedPlayers = room.players.map((p) {
          if (p.uid == uid) {
            return p.copyWith(lastSeen: nowMs);
          }
          return p;
        }).toList();

        await docRef.update({
          'players': updatedPlayers.map((p) => p.toJson()).toList(),
        });
      } catch (e) {
        debugPrint('Failed to update presence: $e');
      }
    } else {
      final room = _localRooms[roomId];
      if (room == null || room.isFinishedOrDismantled) return;

      final updatedPlayers = room.players.map((p) {
        if (p.uid == uid) {
          return p.copyWith(lastSeen: nowMs);
        }
        return p;
      }).toList();

      final updatedRoom = room.copyWith(players: updatedPlayers);
      _localRooms[roomId] = updatedRoom;
      final controller = _getOrCreateLocalStream(roomId);
      if (!controller.isClosed) {
        controller.add(updatedRoom);
      }
    }
  }

  /// Dismantles a room immediately when any user leaves or loses connection.
  Future<void> dismantleRoom({
    required String roomId,
    required String leaverUid,
    String? reason,
  }) async {
    final cleanReason = reason ?? 'Match ended: A player left or disconnected.';

    if (_isFirebaseAvailable) {
      try {
        final docRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);
        final doc = await docRef.get();
        if (!doc.exists || doc.data() == null) return;

        final room = Room.fromJson(doc.data()!);
        if (room.status == RoomStatus.dismantled) return;

        await docRef.update({
          'status': RoomStatus.dismantled.name,
          'dismantledReason': cleanReason,
          'dismantledBy': leaverUid,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Failed to dismantle room $roomId: $e');
      }
    } else {
      final room = _localRooms[roomId];
      if (room == null || room.status == RoomStatus.dismantled) return;

      final updatedRoom = room.copyWith(
        status: RoomStatus.dismantled,
        dismantledReason: cleanReason,
        dismantledBy: leaverUid,
        updatedAt: DateTime.now(),
      );

      _localRooms[roomId] = updatedRoom;
      final controller = _getOrCreateLocalStream(roomId);
      if (!controller.isClosed) {
        controller.add(updatedRoom);
      }
    }
  }

  /// Convenience method called when a user voluntarily leaves a room.
  Future<void> leaveRoom({
    required String roomId,
    required String uid,
    String? reason,
  }) async {
    await dismantleRoom(
      roomId: roomId,
      leaverUid: uid,
      reason: reason ?? 'Player left the room',
    );
  }

  /// Completely removes a room from storage or memory.
  Future<void> deleteRoom(String roomId) async {
    if (_isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance.collection('rooms').doc(roomId).delete();
      } catch (e) {
        debugPrint('Failed to delete room $roomId: $e');
      }
    } else {
      _localRooms.remove(roomId);
      final controller = _localStreams.remove(roomId);
      if (controller != null && !controller.isClosed) {
        controller.close();
      }
    }
  }

  /// Forfeit a room if a player explicitly forfeits.
  Future<void> forfeitRoom({
    required String roomId,
    required String forfeitingUid,
  }) async {
    if (_isFirebaseAvailable) {
      final docRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);
      final doc = await docRef.get();
      if (!doc.exists || doc.data() == null) return;

      final room = Room.fromJson(doc.data()!);
      final otherPlayer = room.players.firstWhere(
        (p) => p.uid != forfeitingUid,
        orElse: () => room.players.first,
      );

      await docRef.update({
        'status': RoomStatus.forfeited.name,
        'winnerUid': otherPlayer.uid,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } else {
      final room = _localRooms[roomId];
      if (room == null) return;

      final otherPlayer = room.players.firstWhere(
        (p) => p.uid != forfeitingUid,
        orElse: () => room.players.first,
      );

      final updatedRoom = room.copyWith(
        status: RoomStatus.forfeited,
        winnerUid: otherPlayer.uid,
        updatedAt: DateTime.now(),
      );

      _localRooms[roomId] = updatedRoom;
      final controller = _getOrCreateLocalStream(roomId);
      if (!controller.isClosed) {
        controller.add(updatedRoom);
      }
    }
  }

  StreamController<Room> _getOrCreateLocalStream(String roomId) {
    var controller = _localStreams[roomId];
    if (controller == null || controller.isClosed) {
      controller = StreamController<Room>.broadcast();
      _localStreams[roomId] = controller;
    }
    return controller;
  }

  @visibleForTesting
  static void resetForTesting() {
    _localRooms.clear();
    for (final controller in _localStreams.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _localStreams.clear();
  }
}
