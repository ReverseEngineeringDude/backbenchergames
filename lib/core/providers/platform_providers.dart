import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_service.dart';
import '../leaderboard/leaderboard_service.dart';
import '../models/leaderboard_entry.dart';
import '../models/room.dart';
import '../models/user_profile.dart';
import '../plugin/game_plugin.dart';
import '../plugin/game_registry.dart';
import '../rooms/room_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final currentUserProvider = StreamProvider<UserProfile?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final roomServiceProvider = Provider<RoomService>((ref) {
  return RoomService();
});

final currentRoomStreamProvider =
    StreamProvider.autoDispose.family<Room?, String>((ref, roomId) {
  final roomService = ref.watch(roomServiceProvider);
  return roomService.listenToRoom(roomId);
});

final leaderboardServiceProvider = Provider<LeaderboardService>((ref) {
  return LeaderboardService();
});

final leaderboardFutureProvider =
    FutureProvider.autoDispose.family<List<LeaderboardEntry>, String>((ref, gameId) {
  final service = ref.watch(leaderboardServiceProvider);
  return service.getLeaderboard(gameId);
});

final leaderboardStreamProvider =
    StreamProvider.autoDispose.family<List<LeaderboardEntry>, String>((ref, gameId) {
  final service = ref.watch(leaderboardServiceProvider);
  return service.streamLeaderboard(gameId);
});

final gameRegistryProvider = Provider<GameRegistry>((ref) {
  return GameRegistry();
});

final availableGamesProvider = Provider<List<GamePlugin>>((ref) {
  final registry = ref.watch(gameRegistryProvider);
  return registry.allGames;
});
