import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

enum MascotMoodState { zen, hyped, anxious, heartbroken }

class AuraMascotWidget extends StatefulWidget {
  final int streak;
  final bool isCompletedToday;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onNavigateToScan;
  final VoidCallback? onNavigateToChat;

  const AuraMascotWidget({
    super.key,
    required this.streak,
    this.isCompletedToday = false,
    this.onDoubleTap,
    this.onNavigateToScan,
    this.onNavigateToChat,
  });

  @override
  State<AuraMascotWidget> createState() => _AuraMascotWidgetState();
}

class _AuraMascotWidgetState extends State<AuraMascotWidget> with TickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  late AnimationController _impactController;
  late Animation<double> _dropYAnimation;
  late Animation<double> _shakeXAnimation;
  late Animation<double> _scaleAnimation;

  bool _isInterrupted = false;
  String _spokenText = "";

  MascotMoodState get _mood {
    if (widget.streak >= 7 && widget.isCompletedToday) {
      return MascotMoodState.hyped;
    } else if (widget.streak >= 1 && widget.isCompletedToday) {
      return MascotMoodState.zen;
    } else if (widget.streak >= 1 && !widget.isCompletedToday) {
      return MascotMoodState.anxious;
    } else {
      return MascotMoodState.heartbroken;
    }
  }

  Color get _auraColor {
    switch (_mood) {
      case MascotMoodState.hyped:
        return const Color(0xFFB300FF); // Electric Gold/Purple
      case MascotMoodState.zen:
        return const Color(0xFF00FFCC); // Cyan Glow
      case MascotMoodState.anxious:
        return const Color(0xFFFF9900); // Warning Amber
      case MascotMoodState.heartbroken:
        return const Color(0xFFFF3366); // Loss Aversion Red
    }
  }

  String get _defaultSubtitle {
    switch (_mood) {
      case MascotMoodState.hyped:
        return "Master Streak Active";
      case MascotMoodState.zen:
        return "Zen Routine Active";
      case MascotMoodState.anxious:
        return "Streak Needs Check-in";
      case MascotMoodState.heartbroken:
        return "Ready for Check-in";
    }
  }

  static const String _mascotLottieAsset = 'assets/lottie/mascot_meditate.json';
  static const String _mascotLottieUrl = 'https://assets9.lottiefiles.com/packages/lf20_q7uarxsb.json';

  void _generateSpokenText() {
    switch (_mood) {
      case MascotMoodState.hyped:
        _spokenText = "Meditation complete! Welcome back to Aura.";
        break;
      case MascotMoodState.zen:
        _spokenText = "Meditation complete! Welcome back to Aura.";
        break;
      case MascotMoodState.anxious:
        _spokenText = "Keep your momentum going! Complete your daily habit.";
        break;
      case MascotMoodState.heartbroken:
        _spokenText = "Welcome back! Let's start your skin routine.";
        break;
    }
  }

  @override
  void initState() {
    super.initState();

    // 1. Continuous Zen Floating Up/Down Animation Loop
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // 2. Tap Reaction Animation (Bounded t in [0.0, 1.0])
    _impactController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _dropYAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 2.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 2.0, end: 4.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 4.0), weight: 2),
    ]).animate(CurvedAnimation(parent: _impactController, curve: Curves.easeOut));

    _shakeXAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _impactController, curve: Curves.easeInOut));

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.95), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 2),
    ]).animate(CurvedAnimation(parent: _impactController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _floatController.dispose();
    _impactController.dispose();
    super.dispose();
  }

  void _handleSingleTap() {
    HapticFeedback.heavyImpact();
    _generateSpokenText();
    _impactController.forward(from: 0.0);
    setState(() {
      _isInterrupted = true;
    });

    Future.delayed(const Duration(milliseconds: 4500), () {
      if (mounted) {
        setState(() {
          _isInterrupted = false;
        });
      }
    });
  }

  void _triggerDoubleTap() {
    if (widget.onNavigateToChat != null) {
      widget.onNavigateToChat!();
    } else if (widget.onDoubleTap != null) {
      widget.onDoubleTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleSingleTap,
      onDoubleTap: _triggerDoubleTap,
      child: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Floating Speech Bubble Overlay (Appears on Single Tap)
            if (_isInterrupted)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                constraints: const BoxConstraints(maxWidth: 160),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _auraColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _auraColor.withOpacity(0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Text(
                  _spokenText.isEmpty ? "Woah! You broke my meditation! 🧘‍♂️⚡ Welcome back to Aura!" : _spokenText,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // Hero Floating Mascot with Dynamic Color-Changing Aura (Original Full Size 120px)
            AnimatedBuilder(
              animation: Listenable.merge([_floatController, _impactController]),
              builder: (context, child) {
                double dropOffset = 0.0;
                if (_impactController.isAnimating) {
                  dropOffset = _dropYAnimation.value;
                } else if (_isInterrupted) {
                  dropOffset = 4.0;
                }

                final double currentY = _floatAnimation.value + dropOffset;
                final double currentX = _impactController.isAnimating ? _shakeXAnimation.value : 0.0;
                final double currentScale = _impactController.isAnimating ? _scaleAnimation.value : 1.0;

                return Transform.translate(
                  offset: Offset(currentX, currentY),
                  child: Transform.scale(
                    scale: currentScale,
                    child: child,
                  ),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _isInterrupted ? _auraColor.withOpacity(0.85) : _auraColor.withOpacity(0.45),
                      blurRadius: _isInterrupted ? 36 : 26,
                      spreadRadius: _isInterrupted ? 5 : 2,
                    ),
                  ],
                ),
                child: Lottie.asset(
                  _mascotLottieAsset,
                  height: 120,
                  width: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Lottie.network(
                    _mascotLottieUrl,
                    height: 120,
                    width: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _auraColor.withOpacity(0.2),
                      ),
                      child: Icon(
                        Icons.spa_rounded,
                        size: 52,
                        color: _auraColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Dynamic Subtitle & Helper Guidance (Constrained so it never squishes mascot)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isInterrupted
                  ? Container(
                      key: const ValueKey('interrupted_badge'),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      constraints: const BoxConstraints(maxWidth: 155),
                      decoration: BoxDecoration(
                        color: _auraColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _auraColor),
                      ),
                      child: Text(
                        "Double Tap to Chat",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _auraColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : Column(
                      key: const ValueKey('default_badge'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          constraints: const BoxConstraints(maxWidth: 155),
                          decoration: BoxDecoration(
                            color: _auraColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _auraColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            _defaultSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _auraColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          "Double Tap to Chat",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
