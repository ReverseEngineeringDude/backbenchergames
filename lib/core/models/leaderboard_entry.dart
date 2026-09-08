/// Generic leaderboard entry representing a player's rank in any game.
class LeaderboardEntry {
  final String uid;
  final String displayName;
  final String avatarUrl;
  final String gameId;
  final int wins;
  final int losses;
  final int draws;
  final int rankScore;
  final int currentStreak;
  final int rank;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    this.avatarUrl = '',
    required this.gameId,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.rankScore,
    this.currentStreak = 0,
    this.rank = 0,
  });

  int get totalGames => wins + losses + draws;

  double get winRate => totalGames == 0 ? 0.0 : (wins / totalGames) * 100;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'gameId': gameId,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'rankScore': rankScore,
        'currentStreak': currentStreak,
        'rank': rank,
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json, {int rank = 0}) {
    return LeaderboardEntry(
      uid: json['uid'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Anonymous',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      gameId: json['gameId'] as String? ?? 'tic_tac_toe',
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      draws: json['draws'] as int? ?? 0,
      rankScore: json['rankScore'] as int? ?? 1000,
      currentStreak: json['currentStreak'] as int? ?? 0,
      rank: (json['rank'] as int?) ?? rank,
    );
  }
}
