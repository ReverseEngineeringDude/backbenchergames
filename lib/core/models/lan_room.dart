/// Represents a LAN/Wi-Fi multiplayer session (no Firebase required).
class LanRoom {
  final String id;
  final String roomCode;
  final String hostIp;
  final int hostPort;
  final String gameId;
  final String hostUid;
  final String hostDisplayName;
  String? guestUid;
  String? guestDisplayName;
  final Map<String, dynamic> stateData;
  final LanRoomStatus status;
  final String? dismantledReason;

  LanRoom({
    required this.id,
    required this.roomCode,
    required this.hostIp,
    required this.hostPort,
    required this.gameId,
    required this.hostUid,
    required this.hostDisplayName,
    required this.stateData,
    required this.status,
    this.guestUid,
    this.guestDisplayName,
    this.dismantledReason,
  });

  /// Creates a dismantled sentinel room.
  factory LanRoom.dismantled({required String reason}) {
    return LanRoom(
      id: '',
      roomCode: '',
      hostIp: '',
      hostPort: 0,
      gameId: '',
      hostUid: '',
      hostDisplayName: '',
      stateData: const {},
      status: LanRoomStatus.dismantled,
      dismantledReason: reason,
    );
  }

  bool get isDismantled => status == LanRoomStatus.dismantled;
  bool get isWaiting => status == LanRoomStatus.waiting;
  bool get isActive => status == LanRoomStatus.active;

  LanRoom copyWith({
    String? id,
    String? roomCode,
    String? hostIp,
    int? hostPort,
    String? gameId,
    String? hostUid,
    String? hostDisplayName,
    String? guestUid,
    String? guestDisplayName,
    Map<String, dynamic>? stateData,
    LanRoomStatus? status,
    String? dismantledReason,
  }) {
    return LanRoom(
      id: id ?? this.id,
      roomCode: roomCode ?? this.roomCode,
      hostIp: hostIp ?? this.hostIp,
      hostPort: hostPort ?? this.hostPort,
      gameId: gameId ?? this.gameId,
      hostUid: hostUid ?? this.hostUid,
      hostDisplayName: hostDisplayName ?? this.hostDisplayName,
      stateData: stateData ?? this.stateData,
      status: status ?? this.status,
      guestUid: guestUid ?? this.guestUid,
      guestDisplayName: guestDisplayName ?? this.guestDisplayName,
      dismantledReason: dismantledReason ?? this.dismantledReason,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': 'state',
        'id': id,
        'roomCode': roomCode,
        'hostIp': hostIp,
        'hostPort': hostPort,
        'gameId': gameId,
        'hostUid': hostUid,
        'hostDisplayName': hostDisplayName,
        'guestUid': guestUid,
        'guestDisplayName': guestDisplayName,
        'stateData': stateData,
        'status': status.name,
        'dismantledReason': dismantledReason,
      };

  factory LanRoom.fromJson(Map<String, dynamic> json) {
    return LanRoom(
      id: json['id'] as String? ?? '',
      roomCode: json['roomCode'] as String? ?? '',
      hostIp: json['hostIp'] as String? ?? '',
      hostPort: (json['hostPort'] as num?)?.toInt() ?? 45678,
      gameId: json['gameId'] as String? ?? '',
      hostUid: json['hostUid'] as String? ?? '',
      hostDisplayName: json['hostDisplayName'] as String? ?? '',
      guestUid: json['guestUid'] as String?,
      guestDisplayName: json['guestDisplayName'] as String?,
      stateData: Map<String, dynamic>.from(
          (json['stateData'] as Map<dynamic, dynamic>?) ?? {}),
      status: LanRoomStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => LanRoomStatus.waiting,
      ),
      dismantledReason: json['dismantledReason'] as String?,
    );
  }
}

enum LanRoomStatus { waiting, active, finished, dismantled }
