import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/user_profile.dart';
import '../theme/app_colors.dart';
import '../widgets/avatar_widget.dart';

class ProfileSheet extends StatefulWidget {
  final UserProfile? user;

  const ProfileSheet({super.key, this.user});

  static Future<void> show(BuildContext context, UserProfile? user) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileSheet(user: user),
    );
  }

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  final _authService = AuthService();
  bool _isEditingName = false;
  late final TextEditingController _nameController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoginMode = true;
  bool _showAuthForm = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.user?.displayName ?? 'Player',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty) {
      await _authService.updateProfile(displayName: newName);
      setState(() => _isEditingName = false);
    }
  }

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill all fields');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLoginMode) {
        await _authService.signInWithEmail(email, password);
      } else {
        await _authService.registerWithEmail(email, password, name);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser ?? widget.user;
    final stats = user?.statsForGame('tic_tac_toe') ?? const GameStats();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1.5)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              if (user != null && !_showAuthForm) ...[
                // Avatar
                AvatarWidget(
                  displayName: user.displayName,
                  size: 70,
                  borderColor: AppColors.playerX,
                ),
                const SizedBox(height: 12),

                // Name & Edit
                if (_isEditingName)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 180,
                        child: TextField(
                          controller: _nameController,
                          autofocus: true,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_rounded,
                            color: AppColors.accentGreen),
                        onPressed: _saveName,
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        color: AppColors.textSecondary,
                        onPressed: () => setState(() => _isEditingName = true),
                      ),
                    ],
                  ),

                Text(
                  user.isAnonymous
                      ? 'Guest Account'
                      : (user.email.isNotEmpty ? user.email : 'Registered Player'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),

                // Stats Grid
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TIC-TAC-TOE STATS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: AppColors.playerX,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Wins', '${stats.wins}', AppColors.accentGreen),
                          _buildStatItem('Losses', '${stats.losses}', Colors.redAccent),
                          _buildStatItem('Draws', '${stats.draws}', AppColors.textSecondary),
                          _buildStatItem('Streak', '${stats.currentStreak}', Colors.orangeAccent),
                          _buildStatItem('Rating', '${stats.rankScore}', AppColors.winGold),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Actions
                if (user.isAnonymous) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withAlpha(80)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Guest accounts are excluded from the global leaderboard. Sign in with Google to enable leaderboard ranking!',
                            style: TextStyle(fontSize: 12, color: Color(0xFFFFD54F), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        try {
                          final signedIn = await _authService.signInWithGoogle();
                          if (signedIn != null && mounted) {
                            navigator.pop();
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() => _errorMessage = 'Google Sign-In failed: $e');
                          }
                        }
                      },
                      icon: const Icon(Icons.g_mobiledata_rounded, color: Color(0xFF4285F4), size: 28),
                      label: const Text('Sign in with Google', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showAuthForm = true),
                      icon: const Icon(Icons.email_outlined, size: 18),
                      label: const Text('Or use Email & Password'),
                    ),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        await _authService.signOut();
                        await _authService.signInAsGuest();
                        if (mounted) navigator.pop();
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign Out'),
                    ),
                  ),
              ] else ...[
                // Auth form for signing in / registration
                Text(
                  _isLoginMode ? 'Sign In' : 'Create Account',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                if (!_isLoginMode)
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Player Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                if (!_isLoginMode) const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitAuth,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isLoginMode ? 'SIGN IN' : 'REGISTER'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _isLoginMode = !_isLoginMode),
                  child: Text(
                    _isLoginMode
                        ? "Don't have an account? Register"
                        : 'Already have an account? Sign In',
                  ),
                ),
                if (user != null)
                  TextButton(
                    onPressed: () => setState(() => _showAuthForm = false),
                    child: const Text('Back to Profile'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
