import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game_config.dart';
import '../tutor_sim_game.dart';

/// Flame overlay built from plain Flutter widgets. Listens to the game's
/// ValueNotifiers so HUD values update in real time.
class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.game});

  final TutorSimGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Capture/miss flash sits underneath the bar+text so the HUD
        // doesn't get washed out.
        Positioned.fill(child: _FlashOverlay(game: game)),
        // Everything informational is non-interactive — the game canvas
        // below should keep pointer/focus.
        IgnorePointer(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC0E1219),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF2A3142),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<int>(
                            valueListenable: game.score,
                            builder: (_, v, _) =>
                                _Stat(label: 'SCORE', value: v.toString()),
                          ),
                          const _Divider(),
                          ValueListenableBuilder<double>(
                            valueListenable: game.timeLeft,
                            builder: (_, v, _) =>
                                _Stat(label: 'TIME', value: _formatTime(v)),
                          ),
                          const _Divider(),
                          ValueListenableBuilder<double>(
                            valueListenable: game.difficulty,
                            builder: (_, v, _) => _Stat(
                              label: 'DIFF',
                              value: 'x${v.toStringAsFixed(1)}',
                              valueColor: _difficultyColor(v),
                            ),
                          ),
                          const _Divider(),
                          ValueListenableBuilder<String>(
                            valueListenable: game.inputDebug,
                            builder: (_, v, _) =>
                                _Stat(label: 'INPUT', value: v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TigMetreBar(game: game),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: ValueListenableBuilder<String?>(
                      valueListenable: game.tigToast,
                      builder: (_, message, _) {
                        if (message == null) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xDD111722),
                            border: Border.all(
                              color: const Color(0xFFFFC03A),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            message,
                            style: const TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _formatTime(double seconds) {
    final s = seconds.ceil().clamp(0, 9999);
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  static Color _difficultyColor(double v) {
    if (v >= 3) return const Color(0xFFFF5C5C);
    if (v >= 2) return const Color(0xFFFFC03A);
    return const Color(0xFFFFFFFF);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8C95A8),
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? const Color(0xFFFFFFFF),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 14),
    color: const Color(0xFF2A3142),
  );
}

/// Full-screen colored sheet that fades from `peakAlpha` to 0 every time
/// the game's `flashTick` increments. Used for capture (white) and miss
/// (red) feedback.
class _FlashOverlay extends StatefulWidget {
  const _FlashOverlay({required this.game});

  final TutorSimGame game;

  @override
  State<_FlashOverlay> createState() => _FlashOverlayState();
}

class _FlashOverlayState extends State<_FlashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Color _color = const Color(0xFFFFFFFF);
  double _peakAlpha = 0.45;
  FlashShape _shape = FlashShape.uniform;
  double _vignetteInnerStop = 0.4;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    widget.game.flashTick.addListener(_onFlash);
  }

  @override
  void dispose() {
    widget.game.flashTick.removeListener(_onFlash);
    _controller.dispose();
    super.dispose();
  }

  void _onFlash() {
    final signal = widget.game.lastFlash;
    if (signal == null) return;
    _color = signal.color;
    _peakAlpha = signal.peakAlpha;
    _shape = signal.shape;
    _vignetteInnerStop = signal.vignetteInnerStop;
    _controller.duration = Duration(milliseconds: signal.durationMs);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) {
          final progress = _controller.value; // 0 → 1
          if (progress >= 1 || progress <= 0) {
            return const SizedBox.shrink();
          }
          // Hold peak alpha for the first 20% of the animation, then
          // linearly fade. Without the hold, the eye only ever sees a
          // partially-faded color and the flash reads as muddy.
          final brightness = progress < 0.2
              ? 1.0
              : (1.0 - (progress - 0.2) / 0.8);
          final tintAlpha = (_peakAlpha * brightness).clamp(0.0, 1.0);
          // Use `withValues` so we don't lose the channel values to a
          // double→int rounding bug. `_color.r` etc. return doubles in
          // 0.0–1.0 in modern Flutter; rounding them to int erases the
          // colour and renders everything near-black.
          final tint = _color.withValues(alpha: tintAlpha);
          switch (_shape) {
            case FlashShape.uniform:
              return ColoredBox(color: tint);
            case FlashShape.vignette:
              // Transparent center → tint at the edges. Gameplay stays
              // visible in the middle while the periphery shows the hue.
              // The inner stop comes from the signal so capture (thin
              // ring) and miss (wide ring) can coexist.
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.95,
                    colors: [Colors.transparent, tint],
                    stops: [_vignetteInnerStop, 1.0],
                  ),
                ),
              );
            case FlashShape.burst:
              // Tint at the center → transparent at the edges. Inverse
              // of [vignette]. Two-stop so the centre stays fully tint.
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.6,
                    colors: [tint, Colors.transparent],
                    stops: const [0.0, 1.0],
                  ),
                ),
              );
          }
        },
      ),
    );
  }
}

/// Bottom-anchored fill bar. Width caps at 520 but shrinks with the
/// viewport so it always fits a narrow window. Wobbles horizontally
/// when the metre is below 25% so the player feels the danger.
class _TigMetreBar extends StatefulWidget {
  const _TigMetreBar({required this.game});

  final TutorSimGame game;

  @override
  State<_TigMetreBar> createState() => _TigMetreBarState();
}

class _TigMetreBarState extends State<_TigMetreBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wobble;

  @override
  void initState() {
    super.initState();
    _wobble = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..repeat();
  }

  @override
  void dispose() {
    _wobble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width - 32;
    final width = maxWidth.clamp(160.0, 520.0);
    return ValueListenableBuilder<double>(
      valueListenable: widget.game.tigMetre,
      builder: (_, value, _) {
        final fraction = (value / GameConfig.tigMetreMax).clamp(0.0, 1.0);
        final isLow = fraction <= 0.25;
        return AnimatedBuilder(
          animation: _wobble,
          builder: (_, _) {
            final dx = isLow
                ? math.sin(_wobble.value * 2 * math.pi) * 3
                : 0.0;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TIG METRE',
                    style: TextStyle(
                      color: isLow
                          ? const Color(0xFFFFC0C0)
                          : const Color(0xFFFFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4,
                      shadows: const [
                        Shadow(
                          blurRadius: 2,
                          color: Color(0xCC000000),
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: width,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xCC0E1219),
                      border: Border.all(
                        color: isLow
                            ? const Color(0xFFFF5C5C)
                            : const Color(0xFF2A3142),
                        width: 2,
                      ),
                    ),
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: fraction,
                          heightFactor: 1,
                          child: ColoredBox(color: _fillColor(fraction)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Color _fillColor(double fraction) {
    if (fraction <= 0.25) return const Color(0xFFFF5C5C);
    if (fraction <= 0.6) return const Color(0xFFFFC03A);
    return const Color(0xFF8BE28B);
  }
}
