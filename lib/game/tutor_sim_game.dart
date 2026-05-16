import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'game_config.dart';
import 'sprites.dart';
import 'students/student_factory.dart';
import 'tutor/tutor_player.dart';
import 'world/cluster_room.dart';

class TutorSimGame extends FlameGame {
  late final ClusterRoom room;

  /// Live set of keys the player is holding. Maintained by main.dart's
  /// HardwareKeyboard event handler. Source of truth for movement and
  /// animation — polled every frame by [TutorPlayer].
  final Set<LogicalKeyboardKey> heldKeys = {};

  // Reactive HUD state. Owned by the game so the Flutter overlay can
  // listen via ValueListenableBuilder.
  final ValueNotifier<int> score = ValueNotifier<int>(GameConfig.startScore);
  final ValueNotifier<int> reputation = ValueNotifier<int>(
    GameConfig.startReputation,
  );
  final ValueNotifier<double> timeLeft = ValueNotifier<double>(
    GameConfig.shiftSeconds,
  );

  /// Debug echo of the active movement keys. Visible in the HUD so we
  /// can immediately see whether key tracking is healthy.
  final ValueNotifier<String> inputDebug = ValueNotifier<String>('-');

  @override
  Future<void> onLoad() async {
    await CharacterSprites.load();

    room = ClusterRoom();
    await world.add(room);

    // Spawn in the walkway between the first two bench rows, not at the
    // room's geometric center (which would overlap a bench).
    final tutor = TutorPlayer(
      position: Vector2(GameConfig.roomWidth / 2, 160),
      room: room,
      heldKeys: heldKeys,
    );
    await world.add(tutor);

    // Wait for room.onLoad so seats are populated before factory runs.
    await room.loaded;
    final students = StudentFactory(room).spawnAll();
    for (final s in students) {
      await world.add(s);
    }

    camera.viewfinder.zoom = GameConfig.cameraZoom;
    camera.follow(tutor);
    camera.setBounds(
      Rectangle.fromLTWH(0, 0, GameConfig.roomWidth, GameConfig.roomHeight),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Refresh the debug HUD from the live held-keys set.
    final parts = <String>[];
    if (_held(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp)) {
      parts.add('W');
    }
    if (_held(LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft)) {
      parts.add('A');
    }
    if (_held(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown)) {
      parts.add('S');
    }
    if (_held(LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight)) {
      parts.add('D');
    }
    inputDebug.value = parts.isEmpty ? '-' : parts.join('');

    if (timeLeft.value > 0) {
      timeLeft.value = (timeLeft.value - dt).clamp(
        0.0,
        GameConfig.shiftSeconds,
      );
    }
  }

  bool _held(LogicalKeyboardKey a, LogicalKeyboardKey b) =>
      heldKeys.contains(a) || heldKeys.contains(b);
}
