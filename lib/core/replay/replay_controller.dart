import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/game_over_result.dart';
import '../models/game_session.dart';
import '../plugin/game_plugin.dart';

/// Generic replay controller that steps through any game's move log
/// without needing any game-specific rules.
class ReplayController extends ChangeNotifier {
  final GameSession session;
  final GamePlugin plugin;
  late final String? _resolvedVariantId;

  int _currentStepIndex = 0;
  dynamic _currentState;
  GameOverResult? _currentGameOverResult;
  bool _isPlaying = false;
  double _speed = 1.0;
  Timer? _playbackTimer;

  ReplayController({
    required this.session,
    required this.plugin,
  }) {
    _resolvedVariantId = plugin.resolveVariantForSession(session);
    _currentState = plugin.initialState(variantId: _resolvedVariantId);
    _currentGameOverResult = plugin.checkGameOver(_currentState);
  }

  int get currentStepIndex => _currentStepIndex;
  int get totalSteps => session.moves.length;
  dynamic get currentState => _currentState;
  GameOverResult? get currentGameOverResult => _currentGameOverResult;
  bool get isPlaying => _isPlaying;
  double get speed => _speed;
  bool get canStepForward => _currentStepIndex < totalSteps;
  bool get canStepBackward => _currentStepIndex > 0;

  void play() {
    if (_isPlaying) return;
    if (!canStepForward) {
      // If at end, restart from beginning
      jumpToStep(0);
    }
    _isPlaying = true;
    notifyListeners();
    _scheduleNextStep();
  }

  void pause() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _isPlaying = false;
    notifyListeners();
  }

  void togglePlay() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void setSpeed(double newSpeed) {
    _speed = newSpeed;
    if (_isPlaying) {
      _playbackTimer?.cancel();
      _scheduleNextStep();
    }
    notifyListeners();
  }

  void _scheduleNextStep() {
    final intervalMs = (900 / _speed).round();
    _playbackTimer = Timer(Duration(milliseconds: intervalMs), () {
      if (!_isPlaying) return;
      if (canStepForward) {
        stepForward();
        _scheduleNextStep();
      } else {
        pause();
      }
    });
  }

  void stepForward() {
    if (!canStepForward) return;

    final moveRecord = session.moves[_currentStepIndex];
    final deserializedMove = plugin.deserializeMove(moveRecord.moveData);
    try {
      _currentState = plugin.applyMove(_currentState, deserializedMove);
    } catch (e) {
      debugPrint('ReplayController: Error applying move at step $_currentStepIndex: $e');
      pause();
      return;
    }
    _currentStepIndex++;
    _currentGameOverResult = plugin.checkGameOver(_currentState);

    notifyListeners();
  }

  void stepBackward() {
    if (!canStepBackward) return;
    jumpToStep(_currentStepIndex - 1);
  }

  void jumpToStep(int targetStep) {
    targetStep = targetStep.clamp(0, totalSteps);
    if (targetStep == _currentStepIndex) return;

    // Recalculate state sequentially from initial state
    dynamic state = plugin.initialState(variantId: _resolvedVariantId);
    for (int i = 0; i < targetStep; i++) {
      final move = plugin.deserializeMove(session.moves[i].moveData);
      try {
        state = plugin.applyMove(state, move);
      } catch (e) {
        debugPrint('ReplayController: Error applying move during jump at step $i: $e');
        break;
      }
    }

    _currentState = state;
    _currentStepIndex = targetStep;
    _currentGameOverResult = plugin.checkGameOver(_currentState);

    notifyListeners();
  }

  void reset() {
    pause();
    jumpToStep(0);
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }
}
