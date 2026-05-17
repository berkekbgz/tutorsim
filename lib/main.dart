import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/tutor_sim_game.dart';
import 'game/ui/auth_overlay.dart';
import 'game/ui/game_over_overlay.dart';
import 'game/ui/hud_overlay.dart';

void main() {
  runApp(const TutorSimApp());
}

class TutorSimApp extends StatefulWidget {
  const TutorSimApp({super.key});

  @override
  State<TutorSimApp> createState() => _TutorSimAppState();
}

class _TutorSimAppState extends State<TutorSimApp> {
  TutorSimGame? _game;
  AuthenticatedGameData? _authData;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  // Maintain our own held-keys set instead of trusting
  // HardwareKeyboard.logicalKeysPressed, which is unreliable on Flutter
  // Web around key repeats and focus changes.
  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      _game?.heldKeys.add(event.logicalKey);
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _game?.captureCurrentEvent();
      }
    } else if (event is KeyUpEvent) {
      _game?.heldKeys.remove(event.logicalKey);
    }
    // KeyRepeatEvent: the key is already in the set, nothing to do.
    return false;
  }

  void _startGame(AuthenticatedGameData data) {
    setState(() {
      _authData = data;
      _game = TutorSimGame(
        tutorLogin: data.user.login,
        studentLogins: data.studentLogins,
      );
    });
  }

  void _restartGame() {
    final data = _authData;
    if (data == null) return;
    setState(() {
      // Drop held keys — the user might be mid-press during the restart.
      _game?.heldKeys.clear();
      _game = TutorSimGame(
        tutorLogin: data.user.login,
        studentLogins: data.studentLogins,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    final theme = ThemeData.dark(useMaterial3: true);

    return MaterialApp(
      title: 'TutorSim',
      debugShowCheckedModeBanner: false,
      theme: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'PressStart2P'),
        primaryTextTheme: theme.primaryTextTheme.apply(
          fontFamily: 'PressStart2P',
        ),
      ),
      home: game == null
          ? LoginPage(onAuthenticated: _startGame)
          : Scaffold(
              backgroundColor: const Color(0xFF0B0E14),
              body: GameWidget<TutorSimGame>(
                game: game,
                overlayBuilderMap: {
                  'hud': (context, game) => HudOverlay(game: game),
                  'gameOver': (context, game) =>
                      GameOverOverlay(game: game, onRestart: _restartGame),
                },
                initialActiveOverlays: const ['hud'],
              ),
            ),
    );
  }
}
