import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/leaderboard_entry.dart';
import '../../core/plugin/game_plugin.dart';
import '../../core/providers/platform_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/skippable_auth_modal.dart';

/// Game-agnostic public leaderboard screen.
class LeaderboardScreen extends ConsumerWidget {
  final GamePlugin plugin;

  const LeaderboardScreen({super.key, required this.plugin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardStreamProvider(plugin.id));
    final currentUser = ref.watch(currentUserProvider).value ?? ref.watch(authServiceProvider).currentUser;
    final isGuest = currentUser == null || currentUser.isAnonymous;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${plugin.displayName} Leaderboard',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                // Guest Warning / Call to Action Banner
                if (isGuest)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amberAccent.withAlpha(120), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amberAccent.withAlpha(25),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.amberAccent.withAlpha(25),
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.amberAccent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Guest Mode (Unranked)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: Colors.amberAccent,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Skipped / Guest players are excluded from the global leaderboard. Sign in with Google to enter rankings!',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => SkippableAuthModal.show(context),
                            child: const Text(
                              'SIGN IN',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                Expanded(
                  child: leaderboardAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.playerX),
                    ),
                    error: (err, stack) => Center(
                      child: Text('Error loading leaderboard: $err'),
                    ),
                    data: (entries) {
                      if (entries.isEmpty) {
                        return const Center(
                          child: Text(
                            'No leaderboard entries yet. Be the first to win!',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        itemCount: entries.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return _LeaderboardTile(entry: entry, rank: index + 1);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;

  const _LeaderboardTile({required this.entry, required this.rank});

  @override
  Widget build(BuildContext context) {
    Color rankColor;
    Widget? rankBadge;

    if (rank == 1) {
      rankColor = AppColors.winGold;
      rankBadge = const Icon(Icons.military_tech_rounded, color: AppColors.winGold, size: 26);
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0);
      rankBadge = const Icon(Icons.military_tech_rounded, color: Color(0xFFC0C0C0), size: 24);
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
      rankBadge = const Icon(Icons.military_tech_rounded, color: Color(0xFFCD7F32), size: 22);
    } else {
      rankColor = AppColors.textSecondary;
      rankBadge = Text(
        '#$rank',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rank <= 3 ? rankColor.withAlpha(120) : AppColors.cardBorder,
          width: rank <= 3 ? 1.5 : 1.0,
        ),
        boxShadow: rank == 1
            ? [
                BoxShadow(
                  color: AppColors.winGoldGlow,
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Rank column
          SizedBox(
            width: 36,
            child: Center(child: rankBadge),
          ),
          const SizedBox(width: 12),

          // Avatar
          AvatarWidget(
            displayName: entry.displayName,
            avatarUrl: entry.avatarUrl,
            size: 42,
            borderColor: rankColor,
          ),
          const SizedBox(width: 14),

          // Player name and record
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.wins}W • ${entry.losses}L • ${entry.draws}D  (${entry.winRate.toStringAsFixed(0)}%)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Score / Rating
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.rankScore}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: rankColor,
                ),
              ),
              if (entry.currentStreak > 1)
                Text(
                  '🔥 ${entry.currentStreak} streak',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
