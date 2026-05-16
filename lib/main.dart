import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/tutor_sim_game.dart';
import 'game/ui/hud_overlay.dart';
import 'game/ui/auth_overlay.dart';

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

  // We maintain our own held-keys set instead of trusting
  // HardwareKeyboard.logicalKeysPressed, which is unreliable on Flutter
  // Web (the set briefly empties around key repeats and focus changes).
  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      _game?.heldKeys.add(event.logicalKey);
    } else if (event is KeyUpEvent) {
      _game?.heldKeys.remove(event.logicalKey);
    }
    // KeyRepeatEvent: key is already in the set, nothing to do.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;

    return MaterialApp(
      title: 'TutorSim',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: game == null
          ? LoginPage(
              onAuthenticated: (data) {
                setState(() {
                  _game = TutorSimGame(
                    tutorLogin: data.user.login,
                    studentLogins: data.studentLogins,
                  );
                });
              },
            )
          : Scaffold(
              backgroundColor: const Color(0xFF0B0E14),
              body: GameWidget<TutorSimGame>(
                game: game,
                overlayBuilderMap: {
                  'hud': (context, game) => HudOverlay(game: game),
                },
                initialActiveOverlays: const ['hud'],
              ),
            ),
    );
  }
}
