// ignore_for_file: deprecated_member_use

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
    RawKeyboard.instance.addListener(_onKey);
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_onKey);
    super.dispose();
  }

  // We maintain our own held-keys set instead of trusting
  // logicalKeysPressed, which is unreliable on Flutter Web around key repeats.
  void _onKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      _game?.heldKeys.add(event.logicalKey);
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _game?.captureCurrentEvent();
      }
    } else if (event is RawKeyUpEvent) {
      _game?.heldKeys.remove(event.logicalKey);
    }
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
