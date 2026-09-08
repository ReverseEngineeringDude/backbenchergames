/// Represents a game variant or configuration (e.g. grid size or rules variation).
class GameVariant {
  final String id;
  final String label;
  final String description;

  const GameVariant({
    required this.id,
    required this.label,
    required this.description,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameVariant &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'GameVariant($id: $label)';
}
