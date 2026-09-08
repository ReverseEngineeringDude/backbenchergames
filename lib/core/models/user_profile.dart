/// Per-game statistics stored inside a user's profile.
class GameStats {
  final int wins;
  final int losses;
  final int draws;
  final int currentStreak;
  final int bestStreak;
  final int rankScore;

  const GameStats({
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.rankScore = 1000,
  });

  int get totalGames => wins + losses + draws;

  double get winRate => totalGames == 0 ? 0.0 : (wins / totalGames) * 100;

  GameStats recordWin() {
    final nextStreak = currentStreak + 1;
    return GameStats(
      wins: wins + 1,
      losses: losses,
      draws: draws,
      currentStreak: nextStreak,
      bestStreak: nextStreak > bestStreak ? nextStreak : bestStreak,
      rankScore: rankScore + 25 + (nextStreak > 2 ? 10 : 0),
    );
  }

  GameStats recordLoss() {
    return GameStats(
      wins: wins,
      losses: losses + 1,
      draws: draws,
      currentStreak: 0,
      bestStreak: bestStreak,
      rankScore: (rankScore - 15).clamp(0, 99999),
    );
  }

  GameStats recordDraw() {
    return GameStats(
      wins: wins,
      losses: losses,
      draws: draws + 1,
      currentStreak: 0,
      bestStreak: bestStreak,
      rankScore: rankScore + 5,
    );
  }

  Map<String, dynamic> toJson() => {
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'rankScore': rankScore,
      };

  factory GameStats.fromJson(Map<String, dynamic> json) {
    return GameStats(
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      draws: json['draws'] as int? ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      rankScore: json['rankScore'] as int? ?? 1000,
    );
  }
}

/// Generic user profile representing users/{uid} in Cloud Firestore.
class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String avatarUrl;
  final DateTime createdAt;
  final Map<String, GameStats> stats;
  final bool isAnonymous;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.avatarUrl = '',
    required this.createdAt,
    this.stats = const {},
    this.isAnonymous = false,
  });

  GameStats statsForGame(String gameId) =>
      stats[gameId] ?? const GameStats();

  UserProfile copyWith({
    String? email,
    String? displayName,
    String? avatarUrl,
    Map<String, GameStats>? stats,
    bool? isAnonymous,
  }) {
    return UserProfile(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      stats: stats ?? this.stats,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'createdAt': createdAt.toIso8601String(),
        'stats': stats.map((key, value) => MapEntry(key, value.toJson())),
        'isAnonymous': isAnonymous,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawStats = json['stats'] as Map<String, dynamic>? ?? {};
    final parsedStats = rawStats.map(
      (key, value) => MapEntry(
        key,
        GameStats.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );

    return UserProfile(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Guest Player',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      stats: parsedStats,
      isAnonymous: json['isAnonymous'] as bool? ?? false,
    );
  }
}
