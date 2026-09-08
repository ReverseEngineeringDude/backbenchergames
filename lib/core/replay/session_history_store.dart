import 'package:flutter/foundation.dart';
import '../models/game_session.dart';

/// In-memory and persisted history of recent game sessions for instant replay.
class SessionHistoryStore extends ChangeNotifier {
  static final SessionHistoryStore _instance = SessionHistoryStore._internal();
  factory SessionHistoryStore() => _instance;
  SessionHistoryStore._internal();

  final List<GameSession> _sessions = [];

  List<GameSession> get sessions => List.unmodifiable(_sessions);

  void recordSession(GameSession session) {
    _sessions.insert(0, session);
    // Keep last 20 sessions
    if (_sessions.length > 20) {
      _sessions.removeLast();
    }
    notifyListeners();
  }

  GameSession? get latestSession => _sessions.isNotEmpty ? _sessions.first : null;
}
