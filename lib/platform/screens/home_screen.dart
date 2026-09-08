import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/ai_difficulty.dart';
import '../../core/models/game_session.dart';
import '../../core/plugin/game_plugin.dart';
import '../../core/plugin/game_registry.dart';
import '../../core/providers/platform_providers.dart';
import '../../core/replay/session_history_store.dart';
import '../../core/rooms/lan_room_service.dart';
import '../../core/rooms/room_service.dart';
import '../theme/app_colors.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/cyber_card.dart';
import 'game_screen.dart';
import 'lan_pairing_screen.dart';
import 'leaderboard_screen.dart';
import 'online_room_screen.dart';
import 'profile_sheet.dart';
import 'replay_screen.dart';
import '../widgets/skippable_auth_modal.dart';

/// Platform Lobby / Home screen. Game-agnostic shell supporting any registered game.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _roomCodeController = TextEditingController();
  bool _hasPromptedAuth = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthPrompt();
    });
  }

  void _checkAuthPrompt() {
    if (_hasPromptedAuth || !mounted) return;
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      _hasPromptedAuth = true;
      SkippableAuthModal.show(context);
    }
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  void _showPassAndPlayDialog(BuildContext context, GamePlugin plugin) {
    final user = ref.read(authServiceProvider).currentUser;

    if (plugin.supportedVariants.isEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            plugin: plugin,
            mode: GamePlayMode.local,
            player1Name: user?.displayName ?? 'Player X',
            player2Name: 'Player O',
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1.5)),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PASS & PLAY',
                  style: TextStyle(
                    color: AppColors.playerX,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose Grid Size',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ...plugin.supportedVariants.map((variant) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CyberCard(
                      padding: const EdgeInsets.all(16),
                      borderColor: AppColors.playerX.withAlpha(90),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GameScreen(
                              plugin: plugin,
                              mode: GamePlayMode.local,
                              initialVariantId: variant.id,
                              player1Name: user?.displayName ?? 'Player X',
                              player2Name: 'Player O',
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.playerX.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.playerX.withAlpha(100),
                              ),
                            ),
                            child: const Icon(
                              Icons.grid_view_rounded,
                              color: AppColors.playerX,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  variant.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  variant.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAiDifficultyDialog(BuildContext context, GamePlugin plugin) {
    String? selectedVariant = plugin.supportedVariants.isNotEmpty
        ? plugin.supportedVariants.first.id
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1.5)),
              ),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (plugin.supportedVariants.isNotEmpty) ...[
                      const Text(
                        'SELECT GRID SIZE',
                        style: TextStyle(
                          color: AppColors.playerX,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: plugin.supportedVariants.map((variant) {
                          final isSel = variant.id == selectedVariant;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: InkWell(
                                onTap: () => setModalState(() => selectedVariant = variant.id),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? AppColors.playerX.withAlpha(35)
                                        : AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSel ? AppColors.playerX : AppColors.cardBorder,
                                      width: isSel ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      variant.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                        color: isSel ? AppColors.playerX : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    const Text(
                      'SELECT AI DIFFICULTY',
                      style: TextStyle(
                        color: AppColors.playerX,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...AIDifficulty.values.map((difficulty) {
                      Color diffColor;
                      if (difficulty == AIDifficulty.easy) {
                        diffColor = AppColors.accentGreen;
                      } else if (difficulty == AIDifficulty.medium) {
                        diffColor = Colors.orangeAccent;
                      } else {
                        diffColor = AppColors.playerO;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CyberCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          borderColor: diffColor.withAlpha(80),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            final currentUser = ref.read(authServiceProvider).currentUser;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GameScreen(
                                  plugin: plugin,
                                  mode: GamePlayMode.vsAi,
                                  aiDifficulty: difficulty,
                                  initialVariantId: selectedVariant,
                                  player1Name: currentUser?.displayName ?? 'Player X',
                                  player2Name: 'AI (${difficulty.displayName})',
                                ),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: diffColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: diffColor.withAlpha(120),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      difficulty.displayName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: diffColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      difficulty.description,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  size: 14, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showOnlineDialog(BuildContext context, GamePlugin plugin) {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    String? selectedVariant = plugin.supportedVariants.isNotEmpty
        ? plugin.supportedVariants.first.id
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1.5)),
                ),
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'ONLINE MULTIPLAYER',
                        style: TextStyle(
                          color: AppColors.playerX,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    if (plugin.supportedVariants.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'GRID RULES',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: plugin.supportedVariants.map((variant) {
                          final isSel = variant.id == selectedVariant;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: InkWell(
                                onTap: () => setModalState(() => selectedVariant = variant.id),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? AppColors.playerX.withAlpha(35)
                                        : AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSel ? AppColors.playerX : AppColors.cardBorder,
                                      width: isSel ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      variant.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                        color: isSel ? AppColors.playerX : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        try {
                          final customState = plugin.serializeState(
                            plugin.initialState(variantId: selectedVariant),
                          );
                          final room = await RoomService().createRoom(
                            gameId: plugin.id,
                            host: user,
                            customInitialState: customState,
                          );
                          if (context.mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => OnlineRoomScreen(
                                  roomId: room.id,
                                  plugin: plugin,
                                  currentUser: user,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to create room: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('CREATE NEW ROOM'),
                    ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.cardBorder)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR JOIN WITH CODE',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ),
                    Expanded(child: Divider(color: AppColors.cardBorder)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _roomCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Enter 6-digit Room Code',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    final code = _roomCodeController.text.trim().toUpperCase();
                    if (code.isEmpty) return;
                    Navigator.of(ctx).pop();
                    _roomCodeController.clear();

                    try {
                      final room = await RoomService().joinRoom(
                        roomCode: code,
                        guest: user,
                      );
                      final roomPlugin = GameRegistry().get(room.gameId) ?? plugin;
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OnlineRoomScreen(
                              roomId: room.id,
                              plugin: roomPlugin,
                              currentUser: user,
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceAll('Exception: ', '')),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('JOIN ROOM'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
},
);
}

  void _showLanDialog(BuildContext context, GamePlugin plugin) {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      SkippableAuthModal.show(context);
      return;
    }

    if (kIsWeb) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.wifi_rounded, color: AppColors.playerX),
              SizedBox(width: 8),
              Text('LAN Mode', style: TextStyle(color: AppColors.textPrimary)),
            ],
          ),
          content: const Text(
            'LAN / Wi-Fi Direct mode is only available in the Android app.\n\nDownload the Android app for full LAN support.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                launchUrl(
                  Uri.parse('https://github.com/your-org/backbenchgames/releases/latest'),
                  mode: LaunchMode.externalApplication,
                );
              },
              icon: const Icon(Icons.android_rounded),
              label: const Text('Get Android App'),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1.5)),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'LAN / WI-FI DIRECT',
                  style: TextStyle(
                    color: AppColors.accentGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Play on the same Wi-Fi',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'No internet needed — play peer-to-peer over your local network.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),

                // HOST button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      final service = LanRoomService();
                      final initialState = plugin.serializeState(plugin.initialState());
                      final room = await service.hostGame(
                        gameId: plugin.id,
                        hostUid: user.uid,
                        hostDisplayName: user.displayName,
                        initialState: initialState,
                      );
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LanHostScreen(
                              room: room,
                              plugin: plugin,
                              service: service,
                              hostUid: user.uid,
                              hostDisplayName: user.displayName,
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to start LAN server: $e'), backgroundColor: Colors.redAccent),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.router_rounded),
                  label: const Text('HOST GAME (Show QR Code)'),
                ),

                const SizedBox(height: 12),

                // JOIN button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.accentGreen, width: 1.5),
                    foregroundColor: AppColors.accentGreen,
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LanJoinScreen(
                          plugin: plugin,
                          guestUid: user.uid,
                          guestDisplayName: user.displayName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('JOIN GAME (Enter IP)'),
                ),

                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Both devices must be on the same Wi-Fi network or hotspot. The Host shows a QR code — Guest scans it or enters the IP manually.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final games = ref.watch(availableGamesProvider);
    final user = ref.watch(currentUserProvider).value ?? ref.watch(authServiceProvider).currentUser;
    final historyStore = SessionHistoryStore();
    final isGuest = user == null || user.isAnonymous;

    final primaryGame = games.isNotEmpty ? games.first : null;

    return Scaffold(
      // ── Hamburger Drawer ────────────────────────────────────────────────
      drawer: _buildDrawer(context, user, primaryGame, isGuest),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 400;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 14 : 20,
                    vertical: isNarrow ? 10 : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  // App Bar Header & Profile Chip

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Hamburger menu button
                          InkWell(
                            onTap: () => Scaffold.of(context).openDrawer(),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: const Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: AppColors.playerX,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'BACKBENCH GAMES',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2.0,
                                      color: AppColors.playerX,
                                    ),
                                  ),
                                ],
                              ),
                              const Text(
                                'Arcade Platform',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // User profile button with rank indicator
                      InkWell(
                        onTap: () => ProfileSheet.show(context, user),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: !isGuest
                                  ? AppColors.playerX.withAlpha(140)
                                  : AppColors.cardBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              AvatarWidget(
                                displayName: user?.displayName ?? 'P',
                                avatarUrl: user?.avatarUrl ?? '',
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    user?.displayName ?? 'Player',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    !isGuest ? '🏆 Ranked' : '⚡ Guest (Unranked)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: !isGuest ? AppColors.winGold : Colors.amberAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Guest Notice Banner
                  if (isGuest) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => SkippableAuthModal.show(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.amberAccent.withAlpha(100)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Colors.amberAccent, size: 18),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Playing as Guest. Sign in with Google to appear on leaderboard.',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  if (primaryGame != null) ...[
                    // Featured Game Hero Card
                    CyberCard(
                      padding: const EdgeInsets.all(20),
                      borderColor: AppColors.playerX.withAlpha(120),
                      glowColor: AppColors.playerXGlow,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.playerX.withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.playerX.withAlpha(120),
                                  ),
                                ),
                                child: const Text(
                                  'FEATURED GAME',
                                  style: TextStyle(
                                    color: AppColors.playerX,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.leaderboard_rounded,
                                    color: AppColors.winGold),
                                tooltip: 'Leaderboard',
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => LeaderboardScreen(
                                        plugin: primaryGame,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Hero(
                            tag: 'game_title_${primaryGame.id}',
                            child: Material(
                              color: Colors.transparent,
                              child: Text(
                                primaryGame.displayName,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            primaryGame.description,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Game modes grid
                          Row(
                            children: [
                              Expanded(
                                child: _ModeButton(
                                  title: 'Pass & Play',
                                  subtitle: 'Local 2 Players',
                                  icon: Icons.people_alt_rounded,
                                  color: AppColors.playerX,
                                  onTap: () =>
                                      _showPassAndPlayDialog(context, primaryGame),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ModeButton(
                                  title: 'vs Computer',
                                  subtitle: '3 AI Levels',
                                  icon: Icons.smart_toy_rounded,
                                  color: AppColors.playerO,
                                  onTap: () =>
                                      _showAiDifficultyDialog(context, primaryGame),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _ModeButton(
                            title: 'Online Multiplayer',
                            subtitle: 'Create or Join Room with Code',
                            icon: Icons.wifi_tethering_rounded,
                            color: AppColors.winGold,
                            isWide: true,
                            onTap: () => _showOnlineDialog(context, primaryGame),
                          ),
                          const SizedBox(height: 12),
                          _ModeButton(
                            title: 'LAN / Wi-Fi Direct',
                            subtitle: 'Same network, no internet needed',
                            icon: Icons.router_rounded,
                            color: AppColors.accentGreen,
                            isWide: true,
                            onTap: () => _showLanDialog(context, primaryGame),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Recent Sessions Replays
                  AnimatedBuilder(
                    animation: historyStore,
                    builder: (context, _) {
                      final sessions = historyStore.sessions;
                      if (sessions.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'RECENT MATCH REPLAYS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...sessions.take(4).map((session) {
                            final winner = session.finalResult?.winner;
                            final isDraw = session.finalResult?.isDraw ?? false;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: CyberCard(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                onTap: () {
                                  final game =
                                      ref.read(gameRegistryProvider).get(session.gameId);
                                  if (game != null) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ReplayScreen(
                                          session: session,
                                          plugin: game,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Row(
                                  children: [
                                    const Icon(Icons.history_rounded,
                                        color: AppColors.playerX, size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${session.player1Name} vs ${session.player2Name}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            isDraw
                                                ? 'Draw Match • ${session.moves.length} moves'
                                                : 'Winner: $winner • ${session.moves.length} moves',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.play_circle_outline_rounded,
                                        color: AppColors.playerX),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Platform Expansion Preview (Upcoming Games)
                  const Text(
                    'MULTI-GAME PLATFORM EXPANSION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _UpcomingGameCard(
                          title: 'Connect Four',
                          icon: Icons.grid_4x4_rounded,
                          color: AppColors.accentPurple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _UpcomingGameCard(
                          title: 'Checkers',
                          icon: Icons.dashboard_customize_rounded,
                          color: AppColors.accentGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    ),
  ),
);
}


  // ── Hamburger Drawer ─────────────────────────────────────────────────────
  Widget _buildDrawer(
    BuildContext context,
    dynamic user,
    dynamic primaryGame,
    bool isGuest,
  ) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.playerX,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'BACKBENCH GAMES',
                        style: TextStyle(
                          color: AppColors.playerX,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.displayName ?? 'Guest',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    !isGuest ? '🏆 Ranked Player' : '⚡ Guest Mode',
                    style: TextStyle(
                      fontSize: 12,
                      color: !isGuest ? AppColors.winGold : Colors.amberAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Menu Items
            ListTile(
              leading: const Icon(Icons.person_rounded, color: AppColors.playerX),
              title: const Text('Profile & Stats', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.of(context).pop();
                ProfileSheet.show(context, user);
              },
            ),

            if (primaryGame != null)
              ListTile(
                leading: const Icon(Icons.leaderboard_rounded, color: AppColors.winGold),
                title: const Text('Leaderboard', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LeaderboardScreen(plugin: primaryGame),
                    ),
                  );
                },
              ),

            const Divider(color: AppColors.cardBorder, height: 24),

            // Download App — prominent on Web, shown always on mobile too
            ListTile(
              leading: const Icon(Icons.android_rounded, color: AppColors.accentGreen),
              title: const Text('Download Android App', style: TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.w700)),
              subtitle: const Text('Better performance & LAN mode', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.textMuted),
              onTap: () async {
                Navigator.of(context).pop();
                final uri = Uri.parse('https://github.com/your-org/backbenchgames/releases/latest');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),

            const Spacer(),
            const Divider(color: AppColors.cardBorder),

            // Sign In / Sign Out
            if (isGuest)
              ListTile(
                leading: const Icon(Icons.login_rounded, color: AppColors.textSecondary),
                title: const Text('Sign In with Google', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  SkippableAuthModal.show(context);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
                title: const Text('Sign Out', style: TextStyle(color: AppColors.textSecondary)),
                onTap: () async {
                  Navigator.of(context).pop();
                  await AuthService().signOut();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}


class _ModeButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isWide;

  const _ModeButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return CyberCard(
      onTap: onTap,
      borderColor: color.withAlpha(60),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isWide ? 16 : 18,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _UpcomingGameCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _UpcomingGameCard({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(120),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color.withAlpha(150), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary.withAlpha(200),
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Plugin Slot Ready',
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
