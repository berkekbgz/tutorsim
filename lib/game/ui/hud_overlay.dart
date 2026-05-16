import 'package:flutter/material.dart';

import '../tutor_sim_game.dart';

/// Flame overlay built from plain Flutter widgets. Listens to the game's
/// ValueNotifiers so HUD values update in real time.
class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.game});

  final TutorSimGame game;

  @override
  Widget build(BuildContext context) {
    // HUD is purely informational — never absorb pointer or focus from
    // the GameWidget below.
    return IgnorePointer(
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
                      ValueListenableBuilder<int>(
                        valueListenable: game.reputation,
                        builder: (_, v, _) => _Stat(
                          label: 'REP',
                          value: v.toString(),
                          valueColor: _reputationColor(v),
                        ),
                      ),
                      const _Divider(),
                      ValueListenableBuilder<double>(
                        valueListenable: game.timeLeft,
                        builder: (_, v, _) =>
                            _Stat(label: 'TIME', value: _formatTime(v)),
                      ),
                      const _Divider(),
                      ValueListenableBuilder<String>(
                        valueListenable: game.inputDebug,
                        builder: (_, v, _) => _Stat(label: 'INPUT', value: v),
                      ),
                    ],
                  ),
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
    );
  }

  static String _formatTime(double seconds) {
    final s = seconds.ceil().clamp(0, 9999);
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  static Color _reputationColor(int v) {
    if (v <= 25) return const Color(0xFFFF5C5C);
    if (v <= 60) return const Color(0xFFFFC03A);
    return const Color(0xFF8BE28B);
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
