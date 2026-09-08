import 'game_plugin.dart';

/// Registry of all playable games on the platform.
class GameRegistry {
  static final GameRegistry _instance = GameRegistry._internal();
  factory GameRegistry() => _instance;
  GameRegistry._internal();

  final Map<String, GamePlugin> _plugins = {};

  /// Register a game plugin.
  void register(GamePlugin plugin) {
    _plugins[plugin.id] = plugin;
  }

  /// Retrieve a game plugin by its unique id.
  GamePlugin? get(String id) => _plugins[id];

  /// Retrieve all registered game plugins.
  List<GamePlugin> get allGames => _plugins.values.toList();

  /// Checks if a game is registered.
  bool hasGame(String id) => _plugins.containsKey(id);
}
