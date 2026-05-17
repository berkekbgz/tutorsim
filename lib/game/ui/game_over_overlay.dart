import 'package:flutter/material.dart';

import '../tutor_sim_game.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    super.key,
    required this.game,
    required this.onRestart,
  });

  final TutorSimGame game;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xCC0B0E14),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF000000), width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                offset: Offset(8, 8),
                blurRadius: 0,
              ),
            ],
          ),
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFE8E1C8),
              border: Border.all(color: const Color(0xFFFFFFFF), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'SHIFT OVER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF171717),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(color: Color(0xFFFFFFFF), offset: Offset(2, 2)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  game.gameOverReason.value ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF5B584A),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                _StatRow(label: 'SCORE', value: game.score.value.toString()),
                _StatRow(
                  label: 'TIGS',
                  value: game.correctTigs.value.toString(),
                ),
                _StatRow(
                  label: 'MISSED',
                  value: game.missedEvents.value.toString(),
                ),
                _StatRow(label: 'TIME', value: _formatElapsed(game.elapsed)),
                _StatRow(
                  label: 'PEAK DIFF',
                  value: 'x${game.difficulty.value.toStringAsFixed(1)}',
                ),
                const SizedBox(height: 22),
                _PixelButton(onPressed: onRestart, label: 'TRY AGAIN'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatElapsed(Duration d) {
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF5B584A),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF171717),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _PixelButton extends StatelessWidget {
  const _PixelButton({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          border: Border.all(color: const Color(0xFF000000), width: 4),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF7E765D),
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}
