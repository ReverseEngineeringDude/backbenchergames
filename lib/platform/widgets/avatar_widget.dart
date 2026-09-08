import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AvatarWidget extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final double size;
  final Color? borderColor;

  const AvatarWidget({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.size = 40,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.playerX.withAlpha(180),
            AppColors.accentPurple.withAlpha(180),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: borderColor ?? AppColors.playerX,
          width: 1.5,
        ),
        image: avatarUrl != null && avatarUrl!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: avatarUrl != null && avatarUrl!.isNotEmpty
          ? null // Image is handled by DecorationImage
          : Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.45,
                ),
              ),
            ),
    );
  }
}
