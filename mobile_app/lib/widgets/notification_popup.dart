import 'package:flutter/material.dart';

class NotificationPopup {
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    Color accentColor = const Color(0xFF00FFCC),
    IconData icon = Icons.spa_rounded,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -100, end: 0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: accentColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.25),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Aura Mascot Avatar Circle
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: accentColor, width: 1.5),
                    ),
                    child: Icon(icon, color: accentColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          message,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                    onPressed: () {
                      if (overlayEntry.mounted) {
                        overlayEntry.remove();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-remove after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  // Duolingo Loss Aversion Trigger
  static void showStreakLossAversion(BuildContext context, int streak) {
    show(
      context,
      title: "🔥 DON'T LOSE YOUR STREAK!",
      message: "Aura is waiting! Your $streak-day skin glow streak is at risk tonight.",
      accentColor: const Color(0xFFFF9900),
      icon: Icons.local_fire_department_rounded,
    );
  }

  // Mascot Recovery Trigger
  static void showMascotRecovery(BuildContext context) {
    show(
      context,
      title: "😢 Aura Misses You!",
      message: "Complete tonight's 2-minute skin routine to earn +50 Glow XP!",
      accentColor: const Color(0xFFFF3366),
      icon: Icons.favorite_rounded,
    );
  }
}
