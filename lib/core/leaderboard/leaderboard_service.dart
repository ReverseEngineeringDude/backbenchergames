import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/leaderboard_entry.dart';

/// Service managing public per-game leaderboards.
class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  bool get _isFirebaseAvailable => Firebase.apps.isNotEmpty;

  // Pre-seeded high scores for offline/demo presentation
  static final Map<String, List<LeaderboardEntry>> _localLeaderboards = {
    'tic_tac_toe': [
      const LeaderboardEntry(
        uid: 'bot_alpha',
        displayName: 'CyberViper',
        gameId: 'tic_tac_toe',
        wins: 48,
        losses: 2,
        draws: 14,
        rankScore: 2450,
        currentStreak: 12,
        rank: 1,
      ),
      const LeaderboardEntry(
        uid: 'bot_beta',
        displayName: 'NeonKnight',
        gameId: 'tic_tac_toe',
        wins: 39,
        losses: 5,
        draws: 8,
        rankScore: 2120,
        currentStreak: 6,
        rank: 2,
      ),
      const LeaderboardEntry(
        uid: 'bot_gamma',
        displayName: 'GlitchMaster',
        gameId: 'tic_tac_toe',
        wins: 31,
        losses: 7,
        draws: 11,
        rankScore: 1890,
        currentStreak: 3,
        rank: 3,
      ),
      const LeaderboardEntry(
        uid: 'bot_delta',
        displayName: 'PulseRider',
        gameId: 'tic_tac_toe',
        wins: 25,
        losses: 9,
        draws: 6,
        rankScore: 1680,
        currentStreak: 1,
        rank: 4,
      ),
      const LeaderboardEntry(
        uid: 'bot_epsilon',
        displayName: 'PixelGhost',
        gameId: 'tic_tac_toe',
        wins: 18,
        losses: 12,
        draws: 4,
        rankScore: 1420,
        currentStreak: 0,
        rank: 5,
      ),
    ],
  };

  /// Real-time stream of leaderboard entries from Cloud Firestore.
  Stream<List<LeaderboardEntry>> streamLeaderboard(String gameId) {
    if (_isFirebaseAvailable) {
      return FirebaseFirestore.instance
          .collection('leaderboard')
          .doc(gameId)
          .collection('entries')
          .orderBy('rankScore', descending: true)
          .limit(50)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          int rank = 1;
          return snapshot.docs.map((doc) {
            final entry = LeaderboardEntry.fromJson(doc.data(), rank: rank);
            rank++;
            return entry;
          }).toList();
        }
        final list = _localLeaderboards[gameId] ?? [];
        list.sort((a, b) => b.rankScore.compareTo(a.rankScore));
        return list;
      }).handleError((e) {
        debugPrint('Error streaming leaderboard from Firestore: $e');
        final list = _localLeaderboards[gameId] ?? [];
        list.sort((a, b) => b.rankScore.compareTo(a.rankScore));
        return list;
      });
    }

    final list = _localLeaderboards[gameId] ?? [];
    list.sort((a, b) => b.rankScore.compareTo(a.rankScore));
    return Stream.value(list);
  }

  /// Fetches top leaderboard entries for [gameId].
  Future<List<LeaderboardEntry>> getLeaderboard(String gameId) async {
    if (_isFirebaseAvailable) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('leaderboard')
            .doc(gameId)
            .collection('entries')
            .orderBy('rankScore', descending: true)
            .limit(50)
            .get();

        if (snapshot.docs.isNotEmpty) {
          int rank = 1;
          return snapshot.docs.map((doc) {
            final entry = LeaderboardEntry.fromJson(doc.data(), rank: rank);
            rank++;
            return entry;
          }).toList();
        }
      } catch (e) {
        debugPrint('Error reading leaderboard from Firestore: $e');
      }
    }

    // Return seeded local data
    final list = _localLeaderboards[gameId] ?? [];
    list.sort((a, b) => b.rankScore.compareTo(a.rankScore));
    return list;
  }

  /// Records a score to the public leaderboard.
  /// CRITICAL: If [isAnonymous] is true (i.e. user skipped Google login),
  /// the score is strictly excluded from Cloud Firestore leaderboard.
  Future<void> recordScore({
    required String gameId,
    required String uid,
    required String displayName,
    String avatarUrl = '',
    required int wins,
    required int losses,
    required int draws,
    required int rankScore,
    required int currentStreak,
    required bool isAnonymous,
  }) async {
    // If user skipped (anonymous / guest), they CANNOT be in the public leaderboard
    if (isAnonymous) {
      debugPrint('Leaderboard: user $uid is a guest/skipped user - excluded from leaderboard.');
      return;
    }

    // Update in-memory fallback list
    recordLocalScore(
      gameId: gameId,
      uid: uid,
      displayName: displayName,
      avatarUrl: avatarUrl,
      wins: wins,
      losses: losses,
      draws: draws,
      rankScore: rankScore,
      currentStreak: currentStreak,
    );

    if (_isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance
            .collection('leaderboard')
            .doc(gameId)
            .collection('entries')
            .doc(uid)
            .set({
          'uid': uid,
          'displayName': displayName,
          'avatarUrl': avatarUrl,
          'gameId': gameId,
          'wins': wins,
          'losses': losses,
          'draws': draws,
          'rankScore': rankScore,
          'currentStreak': currentStreak,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Failed to save score to Firestore leaderboard: $e');
      }
    }
  }

  /// Updates local leaderboard entry for current player (demo/offline mode).
  void recordLocalScore({
    required String gameId,
    required String uid,
    required String displayName,
    String avatarUrl = '',
    required int wins,
    required int losses,
    required int draws,
    required int rankScore,
    required int currentStreak,
  }) {
    final list = _localLeaderboards.putIfAbsent(gameId, () => []);
    list.removeWhere((e) => e.uid == uid);
    list.add(
      LeaderboardEntry(
        uid: uid,
        displayName: displayName,
        avatarUrl: avatarUrl,
        gameId: gameId,
        wins: wins,
        losses: losses,
        draws: draws,
        rankScore: rankScore,
        currentStreak: currentStreak,
      ),
    );
    list.sort((a, b) => b.rankScore.compareTo(a.rankScore));
    for (int i = 0; i < list.length; i++) {
      list[i] = LeaderboardEntry(
        uid: list[i].uid,
        displayName: list[i].displayName,
        avatarUrl: list[i].avatarUrl,
        gameId: list[i].gameId,
        wins: list[i].wins,
        losses: list[i].losses,
        draws: list[i].draws,
        rankScore: list[i].rankScore,
        currentStreak: list[i].currentStreak,
        rank: i + 1,
      );
    }
  }
}
