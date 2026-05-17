import 'package:flutter/material.dart';

import '../../api/score_api.dart';
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
            width: 520,
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
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _LeaderboardPanel(game: game)),
                    const SizedBox(width: 18),
                    Expanded(child: _SneakyNpcsPanel(game: game)),
                  ],
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: game.scoreSyncStatus,
                  builder: (_, status, _) {
                    if (status == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF7E765D),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  },
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

class _LeaderboardPanel extends StatelessWidget {
  const _LeaderboardPanel({required this.game});

  final TutorSimGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<LeaderboardEntry>>(
      valueListenable: game.bestScores,
      builder: (_, entries, _) => _MiniBoard(
        title: 'BEST SCORES',
        empty: 'waiting...',
        rows: [
          for (int i = 0; i < entries.length; i++)
            _BoardRow(
              left: '${i + 1}. ${entries[i].login}',
              right: entries[i].score.toString(),
            ),
        ],
      ),
    );
  }
}

class _SneakyNpcsPanel extends StatelessWidget {
  const _SneakyNpcsPanel({required this.game});

  final TutorSimGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SneakyNpcEntry>>(
      valueListenable: game.sneakyNpcs,
      builder: (_, entries, _) => _MiniBoard(
        title: 'SNEAKY NPCS',
        empty: 'no misses yet',
        rows: [
          for (int i = 0; i < entries.length; i++)
            _BoardRow(
              left: '${i + 1}. ${entries[i].login}',
              right: 'x${entries[i].misses}',
            ),
        ],
      ),
    );
  }
}

class _MiniBoard extends StatelessWidget {
  const _MiniBoard({
    required this.title,
    required this.empty,
    required this.rows,
  });

  final String title;
  final String empty;
  final List<_BoardRow> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE0D6B9),
        border: Border.all(color: const Color(0xFF7E765D), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF5B584A),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Text(
                empty,
                style: const TextStyle(
                  color: Color(0xFF7E765D),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              )
            else
              ...rows,
          ],
        ),
      ),
    );
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({required this.left, required this.right});

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF171717),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            right,
            style: const TextStyle(
              color: Color(0xFF171717),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
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
