import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'game_config.dart';
import 'events/game_event_manager.dart';
import 'sprites.dart';
import 'students/student_factory.dart';
import 'students/student_npc.dart';
import 'students/student_personality.dart';
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
  final List<StudentNpc?> _seatOccupants = [];
  final List<String> _studentLoginQueue = [];
  final Random _random = Random();
  late final TutorPlayer _tutor;
  late final GameEventManager _eventManager;
  final Map<String, int> _tigHoursByLogin = {};
  final Map<StudentNpc, double> _studentStayTimers = {};
  int _populationTargetCount = 0;
  double _tigToastTimer = 0;
  double _nextSpawnIn = GameConfig.studentSpawnIntervalMin;
  bool _spawningStudent = false;

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
    camera.viewfinder.position = _tutor.position.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updateCamera(dt);
    _updatePopulation(dt);

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
    unawaited(student.sayCaught());
    if (_random.nextDouble() < student.personality.quitAfterTigChance) {
      _sendStudentHome(student, showBubble: false);
    }
  }

  bool _held(LogicalKeyboardKey a, LogicalKeyboardKey b) =>
      heldKeys.contains(a) || heldKeys.contains(b);

  void _updateCamera(double dt) {
    if (size.x <= 0 || size.y <= 0) return;

    final target = _tutor.position;
    final t = 1 - exp(-GameConfig.cameraFollowSmoothing * dt);
    final current = camera.viewfinder.position;
    camera.viewfinder.position = current + (target - current) * t;
  }

  Future<void> setStudentLogins(List<String> logins) async {
    if (logins.isEmpty) return;
    await room.loaded;
    for (final student in _students) {
      student.removeFromParent();
    }
    _students.clear();
    _studentStayTimers.clear();
    _studentLoginQueue.clear();
    await _spawnStudents(logins);
  }

  void setTutorLogin(String login) {
    _tutor.setLogin(login);
  }

  StudentNpc? studentAtSeat(int seatIndex) {
    if (seatIndex < 0 || seatIndex >= _seatOccupants.length) return null;
    final student = _seatOccupants[seatIndex];
    if (student == null || !student.isSeated) return null;
    return student;
  }

  Future<void> _spawnStudents(List<String> logins) async {
    _seatOccupants
      ..clear()
      ..addAll(List<StudentNpc?>.filled(room.seats.length, null));
    final initialCount = min(GameConfig.targetStudentCount, room.seats.length);
    _populationTargetCount = min(initialCount, logins.length);
    final initialLogins = logins.take(initialCount).toList();
    _studentLoginQueue.addAll(logins.skip(initialLogins.length));
    final students = StudentFactory(
      room,
      initialLogins,
      releaseSeat: _releaseSeat,
      requestSeat: _requestSeat,
      onExited: _handleStudentExited,
    ).spawnAll();
    _students.addAll(students);
    for (final student in students) {
      final seatIndex = student.currentSeatIndex;
      if (seatIndex != null && seatIndex < _seatOccupants.length) {
        _seatOccupants[seatIndex] = student;
      }
    }
    for (final student in students) {
      _assignStayTimer(student);
      await world.add(student);
    }
  }

  void _updatePopulation(double dt) {
    final transitionInProgress = _students.any(
      (student) => student.isLeavingCluster || !student.isSeated,
    );

    if (!transitionInProgress) {
      for (final student in List<StudentNpc>.of(_students)) {
        if (student.hasExitedCluster || !student.isSeated) continue;

        final nextTime =
            (_studentStayTimers[student] ?? _randomStaySeconds()) - dt;
        if (nextTime <= 0) {
          _sendStudentHome(student);
          break;
        } else {
          _studentStayTimers[student] = nextTime;
        }
      }
    }

    if (_spawningStudent || _studentLoginQueue.isEmpty) return;
    if (_students.length >= _populationTargetCount) return;
    if (transitionInProgress) return;

    _nextSpawnIn -= dt;
    if (_nextSpawnIn > 0) return;

    _nextSpawnIn = _randomSpawnDelay();
    unawaited(_spawnStudentFromGate());
  }

  Future<void> _spawnStudentFromGate() async {
    if (_spawningStudent || _studentLoginQueue.isEmpty) return;
    _spawningStudent = true;
    final login = _studentLoginQueue.removeAt(0);

    final student = StudentNpc(
      login: login,
      position: room.gateSpawnPoint,
      direction: CharacterDirection.down,
      currentSeatIndex: null,
      findPath: room.findPath,
      randomWalkablePoint: room.randomWalkablePoint,
      releaseSeat: _releaseSeat,
      requestSeat: _requestSeat,
      onExited: _handleStudentExited,
    );
    final assignment = _requestSeat(student);
    if (assignment == null || !student.claimSeat(assignment)) {
      _releaseSeat(student);
      _studentLoginQueue.add(login);
      _spawningStudent = false;
      return;
    }

    _students.add(student);
    _assignStayTimer(student);
    await world.add(student);
    _spawningStudent = false;
  }

  void _sendStudentHome(StudentNpc student, {bool showBubble = true}) {
    _studentStayTimers.remove(student);
    student.leaveCluster(room.gateSpawnPoint, showBubble: showBubble);
  }

  void _handleStudentExited(StudentNpc student) {
    _releaseSeat(student);
    _studentStayTimers.remove(student);
    _students.remove(student);
    if (!_studentLoginQueue.contains(student.login)) {
      _studentLoginQueue.add(student.login);
    }
  }

  void _assignStayTimer(StudentNpc student) {
    _studentStayTimers[student] = _randomStaySeconds();
  }

  double _randomStaySeconds() {
    final range =
        GameConfig.studentStayMaxSeconds - GameConfig.studentStayMinSeconds;
    return GameConfig.studentStayMinSeconds + _random.nextDouble() * range;
  }

  double _randomSpawnDelay() {
    final range =
        GameConfig.studentSpawnIntervalMax - GameConfig.studentSpawnIntervalMin;
    return GameConfig.studentSpawnIntervalMin + _random.nextDouble() * range;
  }

  void _releaseSeat(StudentNpc student) {
    final seatIndex = student.currentSeatIndex;
    if (seatIndex == null || seatIndex >= _seatOccupants.length) return;
    if (_seatOccupants[seatIndex] == student) _seatOccupants[seatIndex] = null;
    student.currentSeatIndex = null;
  }

  StudentSeatAssignment? _requestSeat(StudentNpc student) {
    final availableSeats = <int>[];
    for (int i = 0; i < _seatOccupants.length; i++) {
      if (_seatOccupants[i] == null) availableSeats.add(i);
    }
    if (availableSeats.isEmpty) return null;

    final seatIndex = availableSeats[_random.nextInt(availableSeats.length)];
    _seatOccupants[seatIndex] = student;
    return StudentSeatAssignment(
      index: seatIndex,
      position: room.seats[seatIndex].clone(),
      direction: room.seatDirections[seatIndex],
    );
  }
}
