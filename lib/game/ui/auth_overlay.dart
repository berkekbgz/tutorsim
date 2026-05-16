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
      backgroundColor: const Color(0xFF11131A),
      body: Center(
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
            width: 392,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFE8E1C8),
              border: Border.all(color: const Color(0xFFFFFFFF), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/images/42_logo.png',
                  height: 38,
                  filterQuality: FilterQuality.none,
                ),
                const SizedBox(height: 18),
                const Text(
                  'TUTORSIM',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF171717),
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(color: Color(0xFFFFFFFF), offset: Offset(2, 2)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'SIGN IN TO ENTER THE CLUSTER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF5B584A),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 26),
                _body(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: Text(
          'AUTHENTICATING...',
          style: TextStyle(
            color: Color(0xFF171717),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PixelButton(onPressed: _auth.startLogin, label: 'LOGIN WITH 42'),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFF2A1111),
            child: Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFFFB0B0),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
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
