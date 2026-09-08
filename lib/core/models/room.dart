import 'move_record.dart';

enum RoomStatus {
  waiting,
  active,
  finished,
  forfeited,
  dismantled,
}

/// Represents a player participating in an online multiplayer room.
class RoomPlayer {
  final String uid;
  final String displayName;
  final String avatarUrl;
  final String symbol; // e.g. 'X' or 'O'
  final bool isHost;
  final int lastSeen; // Unix timestamp in milliseconds for presence detection

  const RoomPlayer({
    required this.uid,
    required this.displayName,
    this.avatarUrl = '',
    required this.symbol,
    required this.isHost,
    required this.lastSeen,
  });

  RoomPlayer copyWith({
    String? displayName,
    String? avatarUrl,
    String? symbol,
    bool? isHost,
    int? lastSeen,
  }) {
    return RoomPlayer(
      uid: uid,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      symbol: symbol ?? this.symbol,
      isHost: isHost ?? this.isHost,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'symbol': symbol,
        'isHost': isHost,
        'lastSeen': lastSeen,
      };

  factory RoomPlayer.fromJson(Map<String, dynamic> json) {
    return RoomPlayer(
      uid: json['uid'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Player',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      symbol: json['symbol'] as String? ?? 'X',
      isHost: json['isHost'] as bool? ?? false,
      lastSeen: json['lastSeen'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Generic room container for any multiplayer game session on the platform.
class Room {
  final String id;
  final String roomCode;
  final String gameId;
  final String hostUid;
  final List<RoomPlayer> players;
  final RoomStatus status;
  final String currentTurn; // e.g. 'X' or 'O'
  final Map<String, dynamic> stateData;
  final List<MoveRecord> moves;
  final String? winnerUid;
  final bool isDraw;
  final String? dismantledReason;
  final String? dismantledBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Room({
    required this.id,
    required this.roomCode,
    required this.gameId,
    required this.hostUid,
    required this.players,
    required this.status,
    required this.currentTurn,
    required this.stateData,
    this.moves = const [],
    this.winnerUid,
    this.isDraw = false,
    this.dismantledReason,
    this.dismantledBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isFull => players.length >= 2;

  bool get isDismantled => status == RoomStatus.dismantled;

  bool get isFinishedOrDismantled =>
      status == RoomStatus.finished ||
      status == RoomStatus.forfeited ||
      status == RoomStatus.dismantled;

  RoomPlayer? get hostPlayer =>
      players.cast<RoomPlayer?>().firstWhere((p) => p?.isHost == true, orElse: () => null);

  RoomPlayer? get guestPlayer =>
      players.cast<RoomPlayer?>().firstWhere((p) => p?.isHost == false, orElse: () => null);

  RoomPlayer? playerByUid(String uid) =>
      players.cast<RoomPlayer?>().firstWhere((p) => p?.uid == uid, orElse: () => null);

  Room copyWith({
    String? id,
    String? roomCode,
    String? gameId,
    String? hostUid,
    List<RoomPlayer>? players,
    RoomStatus? status,
    String? currentTurn,
    Map<String, dynamic>? stateData,
    List<MoveRecord>? moves,
    String? winnerUid,
    bool? isDraw,
    String? dismantledReason,
    String? dismantledBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Room(
      id: id ?? this.id,
      roomCode: roomCode ?? this.roomCode,
      gameId: gameId ?? this.gameId,
      hostUid: hostUid ?? this.hostUid,
      players: players ?? this.players,
      status: status ?? this.status,
      currentTurn: currentTurn ?? this.currentTurn,
      stateData: stateData ?? this.stateData,
      moves: moves ?? this.moves,
      winnerUid: winnerUid ?? this.winnerUid,
      isDraw: isDraw ?? this.isDraw,
      dismantledReason: dismantledReason ?? this.dismantledReason,
      dismantledBy: dismantledBy ?? this.dismantledBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomCode': roomCode,
        'gameId': gameId,
        'hostUid': hostUid,
        'players': players.map((p) => p.toJson()).toList(),
        'status': status.name,
        'currentTurn': currentTurn,
        'stateData': stateData,
        'moves': moves.map((m) => m.toJson()).toList(),
        'winnerUid': winnerUid,
        'isDraw': isDraw,
        'dismantledReason': dismantledReason,
        'dismantledBy': dismantledBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String? ?? '',
      roomCode: json['roomCode'] as String? ?? '',
      gameId: json['gameId'] as String? ?? 'tic_tac_toe',
      hostUid: json['hostUid'] as String? ?? '',
      players: (json['players'] as List<dynamic>?)
              ?.map((p) => RoomPlayer.fromJson(Map<String, dynamic>.from(p as Map)))
              .toList() ??
          [],
      status: RoomStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => RoomStatus.waiting,
      ),
      currentTurn: json['currentTurn'] as String? ?? 'X',
      stateData: json['stateData'] != null
          ? Map<String, dynamic>.from(json['stateData'] as Map)
          : {},
      moves: (json['moves'] as List<dynamic>?)
              ?.map((m) => MoveRecord.fromJson(Map<String, dynamic>.from(m as Map)))
              .toList() ??
          [],
      winnerUid: json['winnerUid'] as String?,
      isDraw: json['isDraw'] as bool? ?? false,
      dismantledReason: json['dismantledReason'] as String?,
      dismantledBy: json['dismantledBy'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
