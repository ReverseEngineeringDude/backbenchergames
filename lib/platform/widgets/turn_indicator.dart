import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animated Turn Indicator widget that shifts a glowing indicator
/// smoothly between players as turns change.
class TurnIndicator extends StatelessWidget {
  final String player1Name;
  final String player2Name;
  final String? player1Avatar;
  final String? player2Avatar;
  final String player1Symbol;
  final String player2Symbol;
  final bool isPlayer1Turn;
  final int player1Score;
  final int player2Score;

  const TurnIndicator({
    super.key,
    required this.player1Name,
    required this.player2Name,
    this.player1Avatar,
    this.player2Avatar,
    this.player1Symbol = 'X',
    this.player2Symbol = 'O',
    required this.isPlayer1Turn,
    this.player1Score = 0,
    this.player2Score = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      child: Stack(
        children: [
          // Smooth sliding glowing pill indicator
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            alignment: isPlayer1Turn ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPlayer1Turn
                        ? [
                            AppColors.playerX.withAlpha(50),
                            AppColors.playerX.withAlpha(20),
                          ]
                        : [
                            AppColors.playerO.withAlpha(20),
                            AppColors.playerO.withAlpha(50),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPlayer1Turn ? AppColors.playerX : AppColors.playerO,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isPlayer1Turn
                          ? AppColors.playerXGlow
                          : AppColors.playerOGlow,
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Player cards row
          Row(
            children: [
              Expanded(
                child: _PlayerCard(
                  name: player1Name,
                  symbol: player1Symbol,
                  color: AppColors.playerX,
                  isActive: isPlayer1Turn,
                  score: player1Score,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PlayerCard(
                  name: player2Name,
                  symbol: player2Symbol,
                  color: AppColors.playerO,
                  isActive: !isPlayer1Turn,
                  score: player2Score,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final String name;
  final String symbol;
  final Color color;
  final bool isActive;
  final int score;

  const _PlayerCard({
    required this.name,
    required this.symbol,
    required this.color,
    required this.isActive,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Symbol avatar badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha(isActive ? 50 : 25),
              border: Border.all(
                color: color.withAlpha(isActive ? 255 : 120),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                symbol,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name and score
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Score: $score',
                  style: TextStyle(
                    color: isActive ? color : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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
