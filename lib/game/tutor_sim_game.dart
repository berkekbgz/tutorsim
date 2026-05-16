import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'game_config.dart';
import 'events/game_event_manager.dart';
import 'sprites.dart';
import 'students/student_factory.dart';
import 'students/student_npc.dart';
import 'tutor/tutor_player.dart';
import 'world/cluster_room.dart';

class TutorSimGame extends FlameGame {
  TutorSimGame({required this.tutorLogin, required List<String> studentLogins})
    : initialStudentLogins = List.unmodifiable(studentLogins);

  final String tutorLogin;
  final List<String> initialStudentLogins;

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
  final ValueNotifier<String?> tigToast = ValueNotifier<String?>(null);

  final List<StudentNpc> _students = [];
  late final TutorPlayer _tutor;
  late final GameEventManager _eventManager;
  final Map<String, int> _tigHoursByLogin = {};
  double _tigToastTimer = 0;

  int get studentSeatCount => room.seats.length;

  @override
  Future<void> onLoad() async {
    await CharacterSprites.load();

    room = ClusterRoom();
    await world.add(room);

    // Spawn in the walkway between the first two bench rows, not at the
    // room's geometric center (which would overlap a bench).
    _tutor = TutorPlayer(
      position: Vector2(GameConfig.roomWidth / 2, 160),
      room: room,
      heldKeys: heldKeys,
    );
    await world.add(_tutor);
    _tutor.setLogin(tutorLogin);

    // Wait for room.onLoad so seats are populated before factory runs.
    await room.loaded;
    await _spawnStudents(initialStudentLogins);
    _eventManager = GameEventManager(this);
    await world.add(_eventManager);

    camera.viewfinder.zoom = GameConfig.cameraZoom;
    camera.follow(_tutor);
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

    if (_tigToastTimer > 0) {
      _tigToastTimer -= dt;
      if (_tigToastTimer <= 0) tigToast.value = null;
    }
  }

  void captureCurrentEvent() {
    final student = _eventManager.captureNearest(_tutor.position);
    if (student == null) return;

    final hours =
        (_tigHoursByLogin[student.login] ?? 0) + GameConfig.tigHoursPerCapture;
    _tigHoursByLogin[student.login] = hours;
    tigToast.value = '${student.login} got $hours-hour TIG';
    _tigToastTimer = 3;
  }

  bool _held(LogicalKeyboardKey a, LogicalKeyboardKey b) =>
      heldKeys.contains(a) || heldKeys.contains(b);

  Future<void> setStudentLogins(List<String> logins) async {
    if (logins.isEmpty) return;
    await room.loaded;
    for (final student in _students) {
      student.removeFromParent();
    }
    _students.clear();
    await _spawnStudents(logins);
  }

  void setTutorLogin(String login) {
    _tutor.setLogin(login);
  }

  StudentNpc? studentAtSeat(int seatIndex) {
    if (seatIndex < 0 || seatIndex >= _students.length) return null;
    return _students[seatIndex];
  }

  Future<void> _spawnStudents(List<String> logins) async {
    final students = StudentFactory(room, logins).spawnAll();
    _students.addAll(students);
    for (final student in students) {
      await world.add(student);
    }
  }
}
