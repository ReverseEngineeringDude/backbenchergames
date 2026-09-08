import 'package:flutter/material.dart';
import '../../platform/theme/app_colors.dart';
import 'replay_controller.dart';

/// Generic scrubber widget for replaying moves in any game.
class ReplayScrubber extends StatelessWidget {
  final ReplayController controller;

  const ReplayScrubber({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final current = controller.currentStepIndex;
        final total = controller.totalSteps;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress slider and step counter
              Row(
                children: [
                  Text(
                    'Step $current / $total',
                    style: const TextStyle(
                      color: AppColors.playerX,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.playerX,
                        inactiveTrackColor: AppColors.surfaceLight,
                        thumbColor: AppColors.playerX,
                        overlayColor: AppColors.playerXGlow,
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                      ),
                      child: Slider(
                        value: current.toDouble(),
                        min: 0,
                        max: total > 0 ? total.toDouble() : 1.0,
                        divisions: total > 0 ? total : 1,
                        onChanged: total > 0
                            ? (val) => controller.jumpToStep(val.round())
                            : null,
                      ),
                    ),
                  ),
                  // Speed button
                  PopupMenuButton<double>(
                    initialValue: controller.speed,
                    tooltip: 'Playback Speed',
                    onSelected: (speed) => controller.setSpeed(speed),
                    color: AppColors.surfaceLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.cardBorder),
                    ),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 0.5, child: Text('0.5x')),
                      PopupMenuItem(value: 1.0, child: Text('1.0x (Normal)')),
                      PopupMenuItem(value: 1.5, child: Text('1.5x')),
                      PopupMenuItem(value: 2.0, child: Text('2.0x (Fast)')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Text(
                        '${controller.speed}x',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Playback buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Reset to start
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded),
                    color: AppColors.textPrimary,
                    iconSize: 26,
                    tooltip: 'Restart',
                    onPressed: current > 0 ? controller.reset : null,
                  ),
                  const SizedBox(width: 8),

                  // Step backward
                  IconButton(
                    icon: const Icon(Icons.fast_rewind_rounded),
                    color: AppColors.textPrimary,
                    iconSize: 26,
                    tooltip: 'Previous Move',
                    onPressed: controller.canStepBackward
                        ? controller.stepBackward
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // Play / Pause main button
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.playerXGlow,
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(14),
                        backgroundColor: AppColors.playerX,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: controller.togglePlay,
                      child: Icon(
                        controller.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Step forward
                  IconButton(
                    icon: const Icon(Icons.fast_forward_rounded),
                    color: AppColors.textPrimary,
                    iconSize: 26,
                    tooltip: 'Next Move',
                    onPressed: controller.canStepForward
                        ? controller.stepForward
                        : null,
                  ),
                  const SizedBox(width: 8),

                  // Jump to end
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded),
                    color: AppColors.textPrimary,
                    iconSize: 26,
                    tooltip: 'Jump to End',
                    onPressed: current < total
                        ? () => controller.jumpToStep(total)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
