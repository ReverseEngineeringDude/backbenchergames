import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/game_over_result.dart';
import '../../platform/theme/app_colors.dart';
import 'logic.dart';

/// Animated Tic-Tac-Toe Board Widget supporting 3x3, 6x6, and 9x9 grids.
/// Conforms to all animation specifications:
/// - Scale-in + fade (180ms ease-out) on piece placement
/// - Animated winning line drawn across winning cells (350ms)
/// - Dimming of losing cells upon game over
/// - Gentle shake animation on draw
/// - Scoped re-renders per cell
class TicTacToeBoardWidget extends StatefulWidget {
  final TicTacToeState state;
  final void Function(TicTacToeMove move) onMove;
  final bool isInteractive;
  final GameOverResult? gameOverResult;
  final bool isReplay;

  const TicTacToeBoardWidget({
    super.key,
    required this.state,
    required this.onMove,
    this.isInteractive = true,
    this.gameOverResult,
    this.isReplay = false,
  });

  @override
  State<TicTacToeBoardWidget> createState() => _TicTacToeBoardWidgetState();
}

class _TicTacToeBoardWidgetState extends State<TicTacToeBoardWidget>
    with TickerProviderStateMixin {
  late AnimationController _winLineController;
  late Animation<double> _winLineAnimation;

  late AnimationController _drawShakeController;
  late Animation<double> _drawShakeAnimation;

  GameOverResult? _lastGameOverResult;

  @override
  void initState() {
    super.initState();

    _winLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _winLineAnimation = CurvedAnimation(
      parent: _winLineController,
      curve: Curves.easeOutCubic,
    );

    _drawShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _drawShakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _drawShakeController,
        curve: Curves.elasticIn,
      ),
    );

    _handleGameOver(widget.gameOverResult);
  }

  @override
  void didUpdateWidget(covariant TicTacToeBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.gameOverResult != _lastGameOverResult) {
      _handleGameOver(widget.gameOverResult);
    }
  }

  void _handleGameOver(GameOverResult? result) {
    _lastGameOverResult = result;
    if (result != null && result.isOver) {
      if (result.isDraw) {
        _winLineController.reset();
        _drawShakeController.forward(from: 0.0);
      } else if (result.winningIndices != null) {
        _drawShakeController.reset();
        _winLineController.forward(from: 0.0);
      }
    } else {
      _winLineController.reset();
      _drawShakeController.reset();
    }
  }

  @override
  void dispose() {
    _winLineController.dispose();
    _drawShakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameOver = widget.gameOverResult ?? TicTacToeLogic.checkGameOver(widget.state);
    final isGameOver = gameOver.isOver;
    final winningIndices = gameOver.winningIndices;
    final isDraw = gameOver.isDraw;
    final gridSize = widget.state.gridSize;

    // Adapt layout gaps and padding to grid count
    final double gap = gridSize == 3 ? 12.0 : (gridSize == 6 ? 6.0 : 3.5);
    final double padding = gridSize == 3 ? 16.0 : (gridSize == 6 ? 10.0 : 6.0);
    final double cellRadius = gridSize == 3 ? 16.0 : (gridSize == 6 ? 9.0 : 5.0);

    return Center(
      child: AnimatedBuilder(
        animation: _drawShakeAnimation,
        builder: (context, child) {
          // Subtle horizontal shake if draw
          double shakeOffset = 0.0;
          if (_drawShakeController.isAnimating) {
            shakeOffset = math.sin(_drawShakeAnimation.value * math.pi * 6) * 8.0;
          }
          return Transform.translate(
            offset: Offset(shakeOffset, 0),
            child: child,
          );
        },
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withAlpha(200),
              borderRadius: BorderRadius.circular(gridSize == 9 ? 16 : 24),
              border: Border.all(
                color: AppColors.cardBorder.withAlpha(120),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(100),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: EdgeInsets.all(padding),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boardSize = constraints.maxWidth;
                final availableWidth = boardSize;
                final cellSize = (availableWidth - (gridSize - 1) * gap) / gridSize;

                return Stack(
                  children: [
                    // Grid cells
                    GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.state.totalCells,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridSize,
                        crossAxisSpacing: gap,
                        mainAxisSpacing: gap,
                      ),
                      itemBuilder: (context, index) {
                        final mark = widget.state.board[index];
                        final isWinningCell = winningIndices != null &&
                            winningIndices.contains(index);
                        final isDimmed = isGameOver && !isDraw && !isWinningCell;

                        return _AnimatedBoardCell(
                          key: ValueKey('cell_${gridSize}_$index'),
                          index: index,
                          mark: mark,
                          isWinningCell: isWinningCell,
                          isDimmed: isDimmed,
                          isInteractive: widget.isInteractive &&
                              !isGameOver &&
                              mark == null,
                          borderRadius: cellRadius,
                          gridSize: gridSize,
                          onTap: () {
                            if (widget.isInteractive &&
                                !isGameOver &&
                                mark == null) {
                              HapticFeedback.lightImpact();
                              widget.onMove(
                                TicTacToeMove(
                                  index: index,
                                  player: widget.state.currentTurn,
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),

                    // Winning line overlay
                    if (winningIndices != null && winningIndices.length >= 3)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _winLineAnimation,
                            builder: (context, _) {
                              return CustomPaint(
                                painter: _WinningLinePainter(
                                  progress: _winLineAnimation.value,
                                  startIndex: winningIndices.first,
                                  endIndex: winningIndices.last,
                                  gridSize: gridSize,
                                  cellSize: cellSize,
                                  gap: gap,
                                  winner: gameOver.winner ?? 'X',
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Keyed individual cell that animates its content independently.
class _AnimatedBoardCell extends StatefulWidget {
  final int index;
  final String? mark;
  final bool isWinningCell;
  final bool isDimmed;
  final bool isInteractive;
  final double borderRadius;
  final int gridSize;
  final VoidCallback onTap;

  const _AnimatedBoardCell({
    super.key,
    required this.index,
    required this.mark,
    required this.isWinningCell,
    required this.isDimmed,
    required this.isInteractive,
    required this.borderRadius,
    required this.gridSize,
    required this.onTap,
  });

  @override
  State<_AnimatedBoardCell> createState() => _AnimatedBoardCellState();
}

class _AnimatedBoardCellState extends State<_AnimatedBoardCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _placementController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  String? _displayedMark;

  @override
  void initState() {
    super.initState();
    _displayedMark = widget.mark;

    _placementController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _scaleAnimation = Tween<double>(begin: 0.15, end: 1.0).animate(
      CurvedAnimation(
        parent: _placementController,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _placementController,
        curve: Curves.easeOut,
      ),
    );

    if (widget.mark != null) {
      _placementController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedBoardCell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.mark != oldWidget.mark) {
      _displayedMark = widget.mark;
      if (widget.mark != null) {
        _placementController.forward(from: 0.0);
      } else {
        _placementController.reset();
      }
    }
  }

  @override
  void dispose() {
    _placementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWinning = widget.isWinningCell;
    final isDimmed = widget.isDimmed;

    return AnimatedOpacity(
      opacity: isDimmed ? 0.28 : 1.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isInteractive ? widget.onTap : null,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          splashColor: AppColors.playerX.withAlpha(40),
          highlightColor: AppColors.surfaceLight,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: isWinning
                  ? AppColors.winGold.withAlpha(35)
                  : AppColors.surfaceLight.withAlpha(160),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: isWinning
                    ? AppColors.winGold
                    : AppColors.cardBorder.withAlpha(100),
                width: isWinning ? 2.0 : 1.0,
              ),
              boxShadow: isWinning
                  ? [
                      BoxShadow(
                        color: AppColors.winGoldGlow,
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: _displayedMark == null
                  ? const SizedBox.shrink()
                  : AnimatedBuilder(
                      animation: _placementController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: _PieceSymbol(
                        mark: _displayedMark!,
                        isWinning: isWinning,
                        gridSize: widget.gridSize,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom vector drawing of X or O piece with neon glow.
class _PieceSymbol extends StatelessWidget {
  final String mark;
  final bool isWinning;
  final int gridSize;

  const _PieceSymbol({
    required this.mark,
    this.isWinning = false,
    this.gridSize = 3,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWinning
        ? AppColors.winGold
        : (mark == 'X' ? AppColors.playerX : AppColors.playerO);

    final glowColor = isWinning
        ? AppColors.winGoldGlow
        : (mark == 'X' ? AppColors.playerXGlow : AppColors.playerOGlow);

    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeFactor = gridSize == 3 ? 0.65 : (gridSize == 6 ? 0.70 : 0.75);
        final size = math.min(constraints.maxWidth, constraints.maxHeight) * sizeFactor;

        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _SymbolPainter(
              mark: mark,
              color: color,
              glowColor: glowColor,
              gridSize: gridSize,
            ),
          ),
        );
      },
    );
  }
}

class _SymbolPainter extends CustomPainter {
  final String mark;
  final Color color;
  final Color glowColor;
  final int gridSize;

  _SymbolPainter({
    required this.mark,
    required this.color,
    required this.glowColor,
    required this.gridSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeFactor = gridSize == 3 ? 0.16 : (gridSize == 6 ? 0.18 : 0.20);
    final strokeWidth = size.width * strokeFactor;

    // Outer glow paint
    final glowPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth * 1.5
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, gridSize == 9 ? 3 : 5);

    // Foreground solid paint
    final mainPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final center = Offset(size.width / 2, size.height / 2);

    if (mark == 'X') {
      final pad = size.width * 0.10;
      final p1 = Offset(pad, pad);
      final p2 = Offset(size.width - pad, size.height - pad);
      final p3 = Offset(size.width - pad, pad);
      final p4 = Offset(pad, size.height - pad);

      canvas.drawLine(p1, p2, glowPaint);
      canvas.drawLine(p3, p4, glowPaint);

      canvas.drawLine(p1, p2, mainPaint);
      canvas.drawLine(p3, p4, mainPaint);
    } else {
      // Draw 'O' circle
      final radius = (size.width - strokeWidth) / 2;
      canvas.drawCircle(center, radius, glowPaint);
      canvas.drawCircle(center, radius, mainPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SymbolPainter oldDelegate) =>
      oldDelegate.mark != mark ||
      oldDelegate.color != color ||
      oldDelegate.glowColor != glowColor ||
      oldDelegate.gridSize != gridSize;
}

/// Custom painter for smooth animated winning line through cells.
class _WinningLinePainter extends CustomPainter {
  final double progress;
  final int startIndex;
  final int endIndex;
  final int gridSize;
  final double cellSize;
  final double gap;
  final String winner;

  _WinningLinePainter({
    required this.progress,
    required this.startIndex,
    required this.endIndex,
    required this.gridSize,
    required this.cellSize,
    required this.gap,
    required this.winner,
  });

  Offset _getCellCenter(int index) {
    final row = index ~/ gridSize;
    final col = index % gridSize;
    final x = col * (cellSize + gap) + cellSize / 2;
    final y = row * (cellSize + gap) + cellSize / 2;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final start = _getCellCenter(startIndex);
    final end = _getCellCenter(endIndex);

    // Compute interpolated current end point
    final currentEnd = Offset(
      start.dx + (end.dx - start.dx) * progress,
      start.dy + (end.dy - start.dy) * progress,
    );

    final lineWidth = gridSize == 3 ? 6.5 : (gridSize == 6 ? 4.5 : 3.5);
    final glowWidth = lineWidth * 2.2;

    // Neon glowing win line
    final glowPaint = Paint()
      ..color = AppColors.winGoldGlow
      ..strokeWidth = glowWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, gridSize == 9 ? 6 : 10);

    final linePaint = Paint()
      ..color = AppColors.winGold
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, currentEnd, glowPaint);
    canvas.drawLine(start, currentEnd, linePaint);
  }

  @override
  bool shouldRepaint(covariant _WinningLinePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.startIndex != startIndex ||
      oldDelegate.endIndex != endIndex ||
      oldDelegate.gridSize != gridSize;
}
