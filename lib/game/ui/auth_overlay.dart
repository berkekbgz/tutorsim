import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../api/forty_two_auth.dart';
import '../game_config.dart';

class AuthenticatedGameData {
  const AuthenticatedGameData({
    required this.user,
    required this.studentLogins,
  });

  final FortyTwoUser user;
  final List<String> studentLogins;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onAuthenticated});

  final ValueChanged<AuthenticatedGameData> onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FortyTwoAuth _auth = const FortyTwoAuth();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _completeLoginIfNeeded();
  }

  Future<void> _completeLoginIfNeeded() async {
    setState(() {
      _loading = Uri.base.queryParameters.containsKey('code');
      _error = null;
    });

    try {
      final session = await _auth.completeLoginFromCallback();
      if (!mounted || session == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final logins = await _auth.fetchStudentLogins(
        session.token.accessToken,
        campusId: session.user.campusId,
        limit: GameConfig.deskCols * GameConfig.deskRows,
      );
      widget.onAuthenticated(
        AuthenticatedGameData(
          user: session.user,
          studentLogins: logins.isEmpty ? GameConfig.studentLogins : logins,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06080F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _BackgroundLayers(),
          // Decorative cats live in their own layer between the
          // background and the card so they sit behind the central
          // composition and peek out from behind it on small viewports.
          const _DecorativeCats(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _LoginCard(
                    loading: _loading,
                    error: _error,
                    onLogin: _auth.startLogin,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Background ────────────────────────────────────────────────────────────────

class _BackgroundLayers extends StatelessWidget {
  const _BackgroundLayers();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        // Subtle warm halo behind the card area, fading to near-black at
        // the edges. Reads as "the screen is glowing from the center".
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.35,
              colors: [
                Color(0xFF15192B),
                Color(0xFF080B16),
                Color(0xFF02030A),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        _ScanlineOverlay(),
        // Registration marks at each corner — printer/cabinet alignment
        // ornaments, sized so they read as decoration not UI.
        Positioned(top: 28, left: 28, child: _RegMark()),
        Positioned(top: 28, right: 28, child: _RegMark(flipH: true)),
        Positioned(bottom: 28, left: 28, child: _RegMark(flipV: true)),
        Positioned(
          bottom: 28,
          right: 28,
          child: _RegMark(flipH: true, flipV: true),
        ),
      ],
    );
  }
}

class _ScanlineOverlay extends StatelessWidget {
  const _ScanlineOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _ScanlinePainter()));
  }
}

class _ScanlinePainter extends CustomPainter {
  static final _paint = Paint()..color = const Color(0x10000000);

  @override
  void paint(Canvas canvas, Size size) {
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), _paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RegMark extends StatelessWidget {
  const _RegMark({this.flipH = false, this.flipV = false});

  final bool flipH;
  final bool flipV;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF3A4458);
    const mark = SizedBox(
      width: 18,
      height: 18,
      child: Stack(
        children: [
          // Horizontal arm of the corner bracket.
          Positioned(
            top: 0,
            left: 0,
            child: SizedBox(
              width: 18,
              height: 2,
              child: ColoredBox(color: color),
            ),
          ),
          // Vertical arm of the corner bracket.
          Positioned(
            top: 0,
            left: 0,
            child: SizedBox(
              width: 2,
              height: 18,
              child: ColoredBox(color: color),
            ),
          ),
        ],
      ),
    );

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..scaleByDouble(
          flipH ? -1.0 : 1.0,
          flipV ? -1.0 : 1.0,
          1.0,
          1.0,
        ),
      child: mark,
    );
  }
}

// ── Cats ──────────────────────────────────────────────────────────────────────

class _DecorativeCats extends StatelessWidget {
  const _DecorativeCats();

  @override
  Widget build(BuildContext context) {
    // Stagger delays are sequenced after the card logos so cats arrive
    // last, like NPCs settling in. Tilts add hand-placed character.
    // Per-cat bob params are deliberately mismatched (different periods
    // AND different phases) so the group never breathes in unison — it
    // reads as five independent animals, not a single oscillator.
    return const Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 56,
          left: 56,
          child: _Cat(
            asset: 'cat4',
            width: 118,
            height: 132,
            delay: Duration(milliseconds: 540),
            tiltDeg: -4,
            bobAmplitude: 5,
            bobPeriodMs: 1800,
            bobPhase: 0,
          ),
        ),
        Positioned(
          top: 64,
          right: 56,
          child: _Cat(
            asset: 'cat2',
            width: 240,
            height: 195,
            delay: Duration(milliseconds: 620),
            tiltDeg: 5,
            bobAmplitude: 7,
            bobPeriodMs: 2400,
            bobPhase: 1.05,  // ~60°
          ),
        ),
        Positioned(
          bottom: 56,
          left: 56,
          child: _Cat(
            asset: 'cat1',
            width: 240,
            height: 144,
            delay: Duration(milliseconds: 700),
            bobAmplitude: 6,
            bobPeriodMs: 2100,
            bobPhase: 2.10,  // ~120°
          ),
        ),
        Positioned(
          bottom: 64,
          right: 64,
          child: _Cat(
            asset: 'cat3',
            width: 195,
            height: 198,
            delay: Duration(milliseconds: 780),
            tiltDeg: -3,
            bobAmplitude: 8,
            bobPeriodMs: 2600,
            bobPhase: 3.14,  // 180°
          ),
        ),
        Positioned(
          bottom: 220,
          left: 32,
          child: _Cat(
            asset: 'cat5',
            width: 106,
            height: 104,
            delay: Duration(milliseconds: 860),
            tiltDeg: 4,
            bobAmplitude: 5,
            bobPeriodMs: 2000,
            bobPhase: 4.19,  // ~240°
          ),
        ),
      ],
    );
  }
}

class _Cat extends StatefulWidget {
  const _Cat({
    required this.asset,
    required this.width,
    required this.height,
    required this.delay,
    this.tiltDeg = 0,
    this.bobAmplitude = 6,
    this.bobPeriodMs = 2200,
    this.bobPhase = 0,
  });

  final String asset;
  final double width;
  final double height;
  final Duration delay;
  final double tiltDeg;

  /// Peak vertical travel of the bob, in logical pixels.
  final double bobAmplitude;

  /// Full cycle duration in milliseconds. Vary across cats so they
  /// don't sync up over time.
  final int bobPeriodMs;

  /// Starting phase offset in radians (0..2π). Combined with mismatched
  /// periods, this keeps the group looking like independent animals.
  final double bobPhase;

  @override
  State<_Cat> createState() => _CatState();
}

class _CatState extends State<_Cat> with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.bobPeriodMs),
  )..repeat();

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: _Stagger(
        delay: widget.delay,
        child: AnimatedBuilder(
          animation: _bob,
          // The rotate + sized image subtree never changes per frame —
          // pass it as `child` so AnimatedBuilder doesn't rebuild it,
          // only the outer Transform.translate.
          child: Transform.rotate(
            // 0.01745329 rad ≈ 1°. Tiny tilts add personality without
            // breaking pixel-grid alignment too much.
            angle: widget.tiltDeg * 0.01745329,
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: Image.asset(
                'assets/images/${widget.asset}.png',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
          builder: (_, child) {
            final t = _bob.value * 2 * math.pi + widget.bobPhase;
            final dy = math.sin(t) * widget.bobAmplitude;
            return Transform.translate(
              offset: Offset(0, dy),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.loading,
    required this.error,
    required this.onLogin,
  });

  final bool loading;
  final String? error;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0xCC000000),
            offset: Offset(14, 14),
            blurRadius: 0,
          ),
        ],
      ),
      child: Container(
        // Width sized so the [42 — gap — CTJ] row genuinely fits the
        // content area (no overflow → no asymmetric crowding).
        // Math: 328 (42) + 48 (gap) + 248 (CTJ) = 624 row width.
        // Content area = 720 - 80 padding = 640 → 8px each side.
        width: 720,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        decoration: BoxDecoration(
          color: const Color(0xFFEFE6CC),
          border: Border.all(color: const Color(0xFF000000), width: 4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Affiliations row: 42 and CTJ side-by-side at the same
            // height (100) so they read as a matched pair. Sized
            // smaller than the tutorsim title below — they're the
            // "presented by" credit, not the headline.
            _Stagger(
              delay: Duration.zero,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    // 82×25 source @ 100h → 328w.
                    width: 328,
                    height: 100,
                    child: Image.asset(
                      'assets/images/42-logo.png',
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                  const SizedBox(width: 48),
                  SizedBox(
                    // 82×33 source @ 100h → 248w.
                    width: 248,
                    height: 100,
                    child: Image.asset(
                      'assets/images/ctj-logo.png',
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 56),
            // TutorSim title — now the visual headline. 50% taller
            // than the 42/CTJ pair so the eye lands on the game name.
            // 119×29 source @ 150h → 615w.
            _Stagger(
              delay: const Duration(milliseconds: 220),
              child: SizedBox(
                width: 615,
                height: 150,
                child: Image.asset(
                  'assets/images/tutorsim-logo.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ),
            const SizedBox(height: 48),
            _Stagger(
              delay: const Duration(milliseconds: 420),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: loading
                    ? const _LoadingPill(key: ValueKey('loading'))
                    : _PixelButton(
                        key: const ValueKey('button'),
                        onPressed: onLogin,
                        label: 'INSERT 42 TO START',
                      ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 24),
              _ErrorBlock(message: error!),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Stagger reveal ────────────────────────────────────────────────────────────

class _Stagger extends StatefulWidget {
  const _Stagger({required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  State<_Stagger> createState() => _StaggerState();
}

class _StaggerState extends State<_Stagger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (_, child) {
        final t = Curves.easeOutCubic.transform(_ctrl.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 16),
            child: child,
          ),
        );
      },
    );
  }
}

// ── CTA ───────────────────────────────────────────────────────────────────────

class _PixelButton extends StatefulWidget {
  const _PixelButton({
    super.key,
    required this.onPressed,
    required this.label,
  });

  final VoidCallback onPressed;
  final String label;

  @override
  State<_PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<_PixelButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final shadowOffset = _pressed ? Offset.zero : const Offset(6, 6);
    final lift = _pressed ? 0.0 : (_hovered ? -2.0 : 0.0);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, lift, 0),
          decoration: BoxDecoration(
            color: const Color(0xFF101013),
            border: Border.all(color: const Color(0xFF000000), width: 4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD64D2E),
                offset: shadowOffset,
                blurRadius: 0,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
          child: Center(
            child: Text(
              widget.label,
              style: const TextStyle(
                color: Color(0xFFFFE7D5),
                fontFamily: 'PressStart2P',
                fontSize: 14,
                letterSpacing: 2.4,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingPill extends StatefulWidget {
  const _LoadingPill({super.key});

  @override
  State<_LoadingPill> createState() => _LoadingPillState();
}

class _LoadingPillState extends State<_LoadingPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD9D0B5),
        border: Border.all(color: const Color(0xFF000000), width: 4),
      ),
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) {
          final dots = (_ctrl.value * 4).floor() % 4;
          // Pad with spaces so monospace text width stays constant —
          // no layout jitter as the dots cycle.
          final tail = '.' * dots + ' ' * (3 - dots);
          return Text(
            'AUTHENTICATING$tail',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontFamily: 'PressStart2P',
              fontSize: 13,
              letterSpacing: 2,
              height: 1.0,
            ),
          );
        },
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1111),
        border: Border.all(color: const Color(0xFF631414), width: 2),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFFFB0B0),
          fontFamily: 'PressStart2P',
          fontSize: 10,
          height: 1.6,
        ),
      ),
    );
  }
}
