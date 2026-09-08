/// Difficulty levels supported by AI opponents.
enum AIDifficulty {
  easy,
  medium,
  impossible;

  String get displayName {
    switch (this) {
      case AIDifficulty.easy:
        return 'Easy';
      case AIDifficulty.medium:
        return 'Medium';
      case AIDifficulty.impossible:
        return 'Impossible';
    }
  }

  String get description {
    switch (this) {
      case AIDifficulty.easy:
        return 'Random moves. Great for beginners or casual play.';
      case AIDifficulty.medium:
        return 'Smart moves with occasional human-like mistakes (30% randomness).';
      case AIDifficulty.impossible:
        return 'Full minimax with alpha-beta pruning. Unbeatable!';
    }
  }
}
