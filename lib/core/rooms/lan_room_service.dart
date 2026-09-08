import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../models/lan_room.dart';

/// Message types exchanged over the LAN WebSocket connection.
enum LanMsgType { state, move, ping, pong, joined, dismantled }

/// Thrown when LAN mode is invoked on an unsupported platform (web).
class LanUnsupportedError extends UnsupportedError {
  LanUnsupportedError() : super('LAN/Wi-Fi Direct is only available on Android/Desktop builds.');
}

/// Service for LAN multiplayer (WebSocket host ↔ guest).
///
/// Architecture:
///  - **Host** opens a [dart:io] [HttpServer] on port [defaultPort].
///    Clients connect via `ws://<hostIp>:port`.
///  - **Guest** creates a [WebSocketChannel] pointing to the host's address.
///  - All game state is broadcast as JSON [LanMsgType.state] messages.
///  - Heartbeat pings every 5 s; if no pong in 15 s the connection is dismantled.
class LanRoomService {
  static const int defaultPort = 45678;

  // ── Server side (host only) ──────────────────────────────────────────────
  HttpServer? _server;
  WebSocket? _guestSocket;
  final _stateController = StreamController<LanRoom>.broadcast();

  // ── Client side (guest only) ─────────────────────────────────────────────
  WebSocketChannel? _clientChannel;

  // ── Shared ───────────────────────────────────────────────────────────────
  Timer? _pingTimer;
  int _lastPong = 0;
  bool _dismantled = false;

  /// Stream of room-state updates (both host and guest listen to this).
  Stream<LanRoom> get roomStream => _stateController.stream;

  // ══════════════════════════════════════════════════════════════════════════
  //  HOST  ─ runs a WebSocket server
  // ══════════════════════════════════════════════════════════════════════════

  /// Starts a WebSocket server on [port] and returns the local LAN room.
  ///
  /// Throws [LanUnsupportedError] on web.
  Future<LanRoom> hostGame({
    required String gameId,
    required String hostUid,
    required String hostDisplayName,
    required Map<String, dynamic> initialState,
    int port = defaultPort,
  }) async {
    if (kIsWeb) throw LanUnsupportedError();

    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    final localIp = await _localIp();
    final roomCode = _randomCode();

    final room = LanRoom(
      id: roomCode,
      roomCode: roomCode,
      hostIp: localIp,
      hostPort: port,
      gameId: gameId,
      hostUid: hostUid,
      hostDisplayName: hostDisplayName,
      stateData: initialState,
      status: LanRoomStatus.waiting,
    );

    _stateController.add(room);

    // Accept exactly ONE guest connection
    _server!.transform(WebSocketTransformer()).listen((socket) {
      if (_guestSocket != null) {
        socket.close(4001, 'Room full');
        return;
      }
      _guestSocket = socket;
      debugPrint('[LAN Host] Guest connected');

      final updatedRoom = room.copyWith(status: LanRoomStatus.active);
      _stateController.add(updatedRoom);

      // Tell guest the full initial state
      _sendToGuest(updatedRoom.toJson());

      _lastPong = _nowMs();
      _startHostPing(room.copyWith(status: LanRoomStatus.active));

      socket.listen(
        (data) => _onHostReceive(data, room.copyWith(status: LanRoomStatus.active)),
        onDone: () => _dismantleFromHost('Guest disconnected'),
        onError: (_) => _dismantleFromHost('Connection error'),
      );
    });

    return room;
  }

  void _onHostReceive(dynamic raw, LanRoom room) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type'] as String?;
      if (type == 'pong') {
        _lastPong = _nowMs();
      } else if (type == 'move') {
        // Guest calculated the new state and sent it
        if (msg.containsKey('stateData')) {
          final stateData = msg['stateData'] as Map<String, dynamic>;
          final updated = room.copyWith(stateData: stateData);
          // Update local host state and broadcast it back to guest as confirmation
          _stateController.add(updated);
          _sendToGuest(updated.toJson());
        } else {
          debugPrint('[LAN Host] Received old move format. Guest device needs to be updated/rebuilt with the latest code.');
        }
      }
    } catch (e) {
      debugPrint('[LAN Host] parse error: $e');
    }
  }

  void _startHostPing(LanRoom room) {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_dismantled) return;
      _sendToGuest({'type': 'ping'});
      if (_nowMs() - _lastPong > 15000) {
        _dismantleFromHost('Guest timed out');
      }
    });
  }

  void _dismantleFromHost(String reason) {
    if (_dismantled) return;
    _dismantled = true;
    _pingTimer?.cancel();
    _sendToGuest({'type': 'dismantled', 'reason': reason});
    _guestSocket?.close();
    _server?.close(force: true);
    _stateController.add(LanRoom.dismantled(reason: reason));
  }

  void _sendToGuest(Map<String, dynamic> msg) {
    if (_guestSocket?.closeCode == null) {
      _guestSocket?.add(jsonEncode(msg));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GUEST  ─ connects to host's WebSocket server
  // ══════════════════════════════════════════════════════════════════════════

  /// Connects to a host at [hostIp]:[port] and returns after the initial
  /// state message is received (room is active).
  ///
  /// Throws [LanUnsupportedError] on web.
  Future<LanRoom> joinGame({
    required String hostIp,
    required String guestUid,
    required String guestDisplayName,
    int port = defaultPort,
  }) async {
    if (kIsWeb) throw LanUnsupportedError();

    final uri = Uri.parse('ws://$hostIp:$port');
    _clientChannel = IOWebSocketChannel.connect(uri, connectTimeout: const Duration(seconds: 10));

    final completer = Completer<LanRoom>();

    _clientChannel!.stream.listen(
      (data) {
        try {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          final type = msg['type'] as String?;

          if (type == 'ping') {
            _sendToHost({'type': 'pong'});
          } else if (type == 'dismantled') {
            _stateController.add(LanRoom.dismantled(reason: msg['reason'] as String? ?? 'Host left'));
          } else {
            // Full state update
            final room = LanRoom.fromJson(msg);
            if (!completer.isCompleted) completer.complete(room);
            _stateController.add(room);
          }
        } catch (e) {
          debugPrint('[LAN Guest] parse error: $e');
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(Exception('Host closed connection before sending state'));
        }
        _stateController.add(LanRoom.dismantled(reason: 'Host disconnected'));
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    return completer.future.timeout(const Duration(seconds: 12), onTimeout: () {
      throw TimeoutException('Could not reach host within 12 seconds');
    });
  }

  /// Sends updated state data to the host (guest only).
  void sendMove(Map<String, dynamic> stateData) {
    _sendToHost({'type': 'move', 'stateData': stateData});
  }

  void _sendToHost(Map<String, dynamic> msg) {
    _clientChannel?.sink.add(jsonEncode(msg));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Shared helpers
  // ══════════════════════════════════════════════════════════════════════════

  /// Broadcasts a new game state to the guest (host only).
  void broadcastState(LanRoom room) {
    _stateController.add(room);
    _sendToGuest(room.toJson());
  }

  /// Dismantles the LAN session from either side.
  void dismantle({String reason = 'Session ended'}) {
    if (_dismantled) return;
    _dismantled = true;
    _pingTimer?.cancel();
    // Guest path
    _sendToHost({'type': 'dismantled', 'reason': reason});
    _clientChannel?.sink.close();
    // Host path
    _dismantleFromHost(reason);
  }

  Future<void> dispose() async {
    _pingTimer?.cancel();
    _stateController.close();
    await _clientChannel?.sink.close();
    await _guestSocket?.close();
    await _server?.close(force: true);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Utilities
  // ══════════════════════════════════════════════════════════════════════════

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  static String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    return List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Returns the device's first non-loopback IPv4 address.
  static Future<String> _localIp() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  /// Public helper so the QR/join screen can display the host's LAN IP.
  static Future<String> getLocalIp() => _localIp();
}
