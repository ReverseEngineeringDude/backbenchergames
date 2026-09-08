import 'package:flutter/widgets.dart';
import '../models/game_over_result.dart';
import '../models/ai_difficulty.dart';
import '../models/game_variant.dart';
import '../models/game_session.dart';

/// Contract that every game on the platform must implement.
/// This allows the platform core (auth, rooms, leaderboards, replay)
/// to stay 100% agnostic to game-specific rules.
abstract class GamePlugin<S, M> {
  /// Unique identifier for the game, e.g. 'tic_tac_toe'.
  String get id;

  /// Human-readable game title.
  String get displayName;

  /// Tagline or short description.
  String get description;

  /// Min and max players.
  int get minPlayers => 2;
  int get maxPlayers => 2;

  /// Supported AI difficulties for single-player mode.
  List<AIDifficulty> get supportedDifficulties => AIDifficulty.values;

  /// Optional game variants (e.g. grid counts like 3x3, 6x6, 9x9).
  List<GameVariant> get supportedVariants => const [];

  /// Resolves the variant ID to use for replaying or loading a session.
  /// Subclasses can override this to infer the variant from move data or other metadata
  /// if [session.variantId] was omitted or null.
  String? resolveVariantForSession(GameSession session) => session.variantId;

  /// Initial state when a new game session starts, optionally for a [variantId].
  S initialState({String? variantId});

  /// Applies a move to the current state and returns a new state.
  S applyMove(S state, M move);

  /// Validates whether the given move is legal for the current state.
  bool isValidMove(S state, M move);

  /// Checks if the game is in a terminal state (win or draw).
  GameOverResult checkGameOver(S state);

  /// Generates the next move for an AI opponent at the given difficulty.
  M? getAIMove(S state, AIDifficulty difficulty);

  /// Serializes state into a JSON-compatible map for Firestore/network sync.
  Map<String, dynamic> serializeState(S state);

  /// Deserializes state from a JSON map.
  S deserializeState(Map<String, dynamic> json);

  /// Serializes a move into a JSON-compatible map for Firestore and replay logs.
  Map<String, dynamic> serializeMove(M move);

  /// Deserializes a move from a JSON map.
  M deserializeMove(Map<String, dynamic> json);

  /// Constructs the interactive or replay board widget.
  Widget buildBoardWidget({
    required BuildContext context,
    required S state,
    required void Function(M move) onMove,
    required bool isInteractive,
    required String? currentTurnPlayerId,
    required String? localPlayerId,
    M? lastMove,
    GameOverResult? gameOverResult,
    bool isReplay = false,
  });
}
