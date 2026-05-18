import 'dart:async';
import 'dart:math';

import 'package:flame_audio/flame_audio.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../api/score_api.dart';
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

  static const _musicIntro =
      'Exploring The Unknown/xDeviruchi - Exploring The Unknown (Intro).wav';
  static const _musicLoop =
      'Exploring The Unknown/xDeviruchi - Exploring The Unknown (Loop).wav';
  static const _musicEnd =
      'Exploring The Unknown/xDeviruchi - Exploring The Unknown (End).wav';
  static const _musicVolume = 0.45;

  // Short SFX. Filenames are relative to the FlameAudio prefix
  // (`assets/`), which is set in `_startBackgroundMusic`.
  static const _sfxBump = 'Bump.wav';
  static const _sfxBossHit = 'Boss hit 1.wav';
  static const _sfxAlarm = 'Digital_Alarm.wav';
  static const _sfxSplash = 'Water_Splash.wav';
  static const _sfxCoin = 'driken5482-retro-coin-4-236671.mp3';

  static final AudioContext _sfxAudioContext = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();

  late final ClusterRoom room;

  /// Live set of keys the player is holding. Maintained by main.dart's
  /// HardwareKeyboard event handler. Source of truth for movement and
  /// animation — polled every frame by [TutorPlayer].
  final Set<LogicalKeyboardKey> heldKeys = {};

  // Reactive HUD state. Owned by the game so the Flutter overlay can
  // listen via ValueListenableBuilder.
  final ValueNotifier<int> score = ValueNotifier<int>(GameConfig.startScore);

  /// The lose-condition meter. Drains by [GameConfig.tigMetreDrainPerSecond]
  /// every second, drops by [GameConfig.tigMetreLossPerMissedEvent] on a
  /// missed event, and refills by [GameConfig.tigMetreGainPerCorrectTig]
  /// on a successful TIG. Reaching zero ends the run.
  final ValueNotifier<double> tigMetre = ValueNotifier<double>(
    GameConfig.tigMetreStart.toDouble(),
  );
  /// Wall-clock seconds the player has survived in this run. Runs
  /// indefinitely — there's no shift cap any more. Mirrors the private
  /// `_elapsed` counter so the HUD can read it via ValueListenableBuilder.
  final ValueNotifier<double> elapsedSeconds = ValueNotifier<double>(0);

  /// Debug echo of the active movement keys. Visible in the HUD so we
  /// can immediately see whether key tracking is healthy.
  final ValueNotifier<String> inputDebug = ValueNotifier<String>('-');
  final ValueNotifier<String?> tigToast = ValueNotifier<String?>(null);

  /// Time-driven difficulty multiplier. Ramps from
  /// [GameConfig.difficultyMin] at game start to [GameConfig.difficultyMax]
  /// after [GameConfig.difficultyRampSeconds], then plateaus. Read by
  /// [GameEventManager] to scale spawn rate, concurrent cap, and expiry.
  final ValueNotifier<double> difficulty = ValueNotifier<double>(
    GameConfig.difficultyMin,
  );

  /// Flips true the first time a game-over condition is hit. The HUD's
  /// Flame overlay reacts by mounting the game-over screen.
  final ValueNotifier<bool> gameOver = ValueNotifier<bool>(false);
  final ValueNotifier<String?> gameOverReason = ValueNotifier<String?>(null);

  final ValueNotifier<int> correctTigs = ValueNotifier<int>(0);
  final ValueNotifier<int> missedEvents = ValueNotifier<int>(0);
  final ValueNotifier<List<LeaderboardEntry>> bestScores = ValueNotifier(
    <LeaderboardEntry>[],
  );
  final ValueNotifier<List<SneakyNpcEntry>> sneakyNpcs = ValueNotifier(
    <SneakyNpcEntry>[],
  );
  final ValueNotifier<String?> scoreSyncStatus = ValueNotifier(null);

  /// Counter incremented every time a flash is requested. Read with
  /// [lastFlash] for the actual color/peak alpha. Using a counter lets
  /// the listener fire even for repeated identical flashes.
  final ValueNotifier<int> flashTick = ValueNotifier<int>(0);
  FlashSignal? lastFlash;

  final List<StudentNpc> _students = [];
  final List<StudentNpc?> _seatOccupants = [];
  final List<String> _studentLoginQueue = [];
  final Random _random = Random();
  late final TutorPlayer _tutor;
  late final GameEventManager _eventManager;
  final Map<String, int> _tigHoursByLogin = {};
  final Map<String, int> _missedEventsByLogin = {};
  final Map<StudentNpc, double> _studentStayTimers = {};
  int _populationTargetCount = 0;
  double _tigToastTimer = 0;
  double _nextSpawnIn = GameConfig.studentSpawnIntervalMin;
  bool _spawningStudent = false;
  bool _submittedScore = false;
  bool _musicStarted = false;
  bool _endingMusic = false;
  AudioPlayer? _introPlayer;
  AudioPlayer? _endPlayer;
  AudioPool? _bumpPool;
  AudioPool? _bossHitPool;
  AudioPool? _alarmPool;
  AudioPool? _splashPool;
  AudioPool? _coinPool;
  double _elapsed = 0;
  double _shakeMagnitude = 0;
  double _shakeTimeLeft = 0;
  double _shakeTotalTime = 0;

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

    await _startBackgroundMusic();
  }

  @override
  void onRemove() {
    unawaited(FlameAudio.bgm.stop());
    unawaited(_introPlayer?.dispose() ?? Future<void>.value());
    unawaited(_endPlayer?.dispose() ?? Future<void>.value());
    unawaited(_bumpPool?.dispose() ?? Future<void>.value());
    unawaited(_bossHitPool?.dispose() ?? Future<void>.value());
    unawaited(_alarmPool?.dispose() ?? Future<void>.value());
    unawaited(_splashPool?.dispose() ?? Future<void>.value());
    unawaited(_coinPool?.dispose() ?? Future<void>.value());
    super.onRemove();
  }

  @override
  void update(double dt) {
    // When the shift is over, freeze the entire world: students stop
    // moving, events stop spawning, tutor input stops mattering. The
    // game-over overlay (Flutter widget) keeps rendering on top.
    if (gameOver.value) return;
    super.update(dt);
    _updateCamera(dt);
    _updatePopulation(dt);
    _elapsed += dt;
    elapsedSeconds.value = _elapsed;
    difficulty.value = _computeDifficulty(_elapsed);

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

    // Continuous TIG metre drain, scaled by current difficulty so time
    // pressure compounds as the run goes on. Missed events deduct in
    // [notifyMissedEvent]; correct TIGs refill in [captureCurrentEvent].
    final drained =
        tigMetre.value -
        GameConfig.tigMetreDrainPerSecond * difficulty.value * dt;
    tigMetre.value = drained.clamp(0.0, GameConfig.tigMetreMax.toDouble());
    if (tigMetre.value <= 0) _endGame('TIG metre drained');

    if (_tigToastTimer > 0) {
      _tigToastTimer -= dt;
      if (_tigToastTimer <= 0) tigToast.value = null;
    }
  }

  double _computeDifficulty(double elapsedSeconds) {
    final t = (elapsedSeconds / GameConfig.difficultyRampSeconds).clamp(
      0.0,
      1.0,
    );
    return GameConfig.difficultyMin +
        (GameConfig.difficultyMax - GameConfig.difficultyMin) * t;
  }

  void captureCurrentEvent() {
    if (gameOver.value) return;
    final capture = _eventManager.captureNearest(_tutor.position);
    if (capture == null) return;
    final student = capture.student;
    if (student == null) return;

    final hours =
        (_tigHoursByLogin[student.login] ?? 0) + GameConfig.tigHoursPerCapture;
    _tigHoursByLogin[student.login] = hours;
    score.value += GameConfig.scorePerCorrectTig;
    tigMetre.value = (tigMetre.value + GameConfig.tigMetreGainPerCorrectTig)
        .clamp(0.0, GameConfig.tigMetreMax.toDouble());
    correctTigs.value += 1;
    tigToast.value = '${student.login} got $hours-hour TIG';
    _tigToastTimer = 3;
    // No screen flash on capture — feedback comes from the toast,
    // the TIG metre filling, and the score ticking up. The red miss
    // vignette is the only screen-tinting effect, which keeps it
    // unambiguous: tinted screen = bad.
    // Capture SFX is event-specific: sleep gets the splash (a "snap out
    // of it" cue), everything else gets the generic retro-coin chime.
    final captureSfx = capture.kindId == 'sleep' ? _sfxSplash : _sfxCoin;
    unawaited(_playSfx(captureSfx, volume: 0.7));
    unawaited(student.sayCaught());
    if (_random.nextDouble() < student.personality.quitAfterTigChance) {
      _sendStudentHome(student, showBubble: false);
    }
  }

  Future<void> _startBackgroundMusic() async {
    if (_musicStarted) return;
    _musicStarted = true;
    FlameAudio.updatePrefix('assets/');
    await FlameAudio.bgm.initialize();
    await _prepareSfxPools();
    _introPlayer = await FlameAudio.playLongAudio(
      _musicIntro,
      volume: _musicVolume,
    );
    unawaited(_startLoopAfterIntro(_introPlayer!));
  }

  Future<void> _prepareSfxPools() async {
    final pools = await Future.wait([
      _createSfxPool(_sfxBump, minPlayers: 3, maxPlayers: 6),
      _createSfxPool(_sfxBossHit, minPlayers: 2, maxPlayers: 4),
      _createSfxPool(_sfxAlarm, minPlayers: 2, maxPlayers: 3),
      _createSfxPool(_sfxSplash, minPlayers: 2, maxPlayers: 4),
      _createSfxPool(_sfxCoin, minPlayers: 2, maxPlayers: 4),
    ]);
    _bumpPool = pools[0];
    _bossHitPool = pools[1];
    _alarmPool = pools[2];
    _splashPool = pools[3];
    _coinPool = pools[4];
  }

  Future<AudioPool> _createSfxPool(
    String filename, {
    required int minPlayers,
    required int maxPlayers,
  }) {
    return AudioPool.create(
      source: AssetSource(filename),
      audioCache: FlameAudio.audioCache,
      minPlayers: minPlayers,
      maxPlayers: maxPlayers,
      playerMode: PlayerMode.lowLatency,
      audioContext: _sfxAudioContext,
    );
  }

  Future<void> _playSfx(String filename, {double volume = 0.7}) async {
    if (gameOver.value && filename != _sfxBossHit) return;
    try {
      final pool = _sfxPoolFor(filename);
      if (pool == null) {
        await FlameAudio.play(filename, volume: volume);
        return;
      }

      await _startPooledSfx(pool, filename, volume: volume);
    } catch (error) {
      debugPrint('SFX $filename failed: $error');
    }
  }

  void notifyDeskEventStarted() {
    unawaited(_playSfx(_sfxBump, volume: 0.75));
  }

  AudioPool? _sfxPoolFor(String filename) {
    return switch (filename) {
      _sfxBump => _bumpPool,
      _sfxBossHit => _bossHitPool,
      _sfxAlarm => _alarmPool,
      _sfxSplash => _splashPool,
      _sfxCoin => _coinPool,
      _ => null,
    };
  }

  Duration _sfxAutoStopDelay(String filename) {
    return switch (filename) {
      _sfxBossHit => const Duration(milliseconds: 350),
      _sfxBump => const Duration(milliseconds: 250),
      _sfxSplash => const Duration(milliseconds: 550),
      _sfxAlarm => const Duration(milliseconds: 800),
      // Coin clip is ~183ms; small tail margin so the full chime plays
      // before the pool player is rearmed for the next capture.
      _sfxCoin => const Duration(milliseconds: 220),
      _ => const Duration(milliseconds: 1000),
    };
  }

  /// Called by [GameEventManager] when an active event is about to
  /// expire. Plays only the opening 800ms of the alarm. The caller gets
  /// back a stop function so it can cut the alarm early if the player
  /// captures the event before the clip ends.
  Future<StopFunction?> notifyEventAboutToExpire() {
    if (gameOver.value) return Future.value(null);
    return _playSfxWithStop(_sfxAlarm, volume: 0.55);
  }

  Future<StopFunction?> _playSfxWithStop(
    String filename, {
    double volume = 0.7,
  }) async {
    if (gameOver.value) return null;
    try {
      final pool = _sfxPoolFor(filename);
      if (pool == null) {
        final player = await FlameAudio.play(filename, volume: volume);
        return player.stop;
      }

      return _startPooledSfx(pool, filename, volume: volume);
    } catch (error) {
      debugPrint('SFX $filename failed: $error');
      return null;
    }
  }

  Future<StopFunction> _startPooledSfx(
    AudioPool pool,
    String filename, {
    required double volume,
  }) async {
    final rawStop = await pool.start(volume: volume);
    var stopped = false;
    Timer? timer;

    Future<void> stop() async {
      if (stopped) return;
      stopped = true;
      timer?.cancel();
      await rawStop();
    }

    timer = Timer(_sfxAutoStopDelay(filename), () {
      unawaited(stop());
    });
    return stop;
  }

  Future<void> _startLoopAfterIntro(AudioPlayer introPlayer) async {
    await introPlayer.onPlayerComplete.first;
    if (_introPlayer == introPlayer) _introPlayer = null;
    await introPlayer.dispose();
    if (_endingMusic || gameOver.value || isRemoved) return;
    await FlameAudio.bgm.play(_musicLoop, volume: _musicVolume);
  }

  Future<void> _playEndMusic() async {
    if (_endingMusic) return;
    _endingMusic = true;
    await FlameAudio.bgm.stop();
    final introPlayer = _introPlayer;
    _introPlayer = null;
    await introPlayer?.dispose();
    await _endPlayer?.dispose();
    _endPlayer = await FlameAudio.playLongAudio(
      _musicEnd,
      volume: _musicVolume,
    );
  }

  /// Called by the event manager when an event expires without the
  /// player capturing it. Score takes a hit; TIG metre takes a bigger one.
  void notifyMissedEvent(StudentNpc? student) {
    if (gameOver.value) return;
    score.value = (score.value + GameConfig.scorePerMissedEvent).clamp(
      0,
      1 << 30,
    );
    tigMetre.value = (tigMetre.value - GameConfig.tigMetreLossPerMissedEvent)
        .clamp(0.0, GameConfig.tigMetreMax.toDouble());
    missedEvents.value += 1;
    if (student != null) {
      _missedEventsByLogin[student.login] =
          (_missedEventsByLogin[student.login] ?? 0) + 1;
    }
    _triggerFlash(
      const FlashSignal(
        color: Color(0xFFFF3344),
        peakAlpha: 0.7,
        durationMs: 420,
        shape: FlashShape.vignette,
      ),
    );
    _triggerShake(magnitude: 13, seconds: 0.32);
    unawaited(_playSfx(_sfxBossHit, volume: 0.85));
    if (tigMetre.value <= 0) _endGame('TIG metre drained');
  }

  void _triggerFlash(FlashSignal signal) {
    lastFlash = signal;
    flashTick.value = flashTick.value + 1;
  }

  void _triggerShake({required double magnitude, required double seconds}) {
    // If a shake is already running, only escalate — never weaken it.
    final remainingMag = _shakeTotalTime > 0
        ? _shakeMagnitude * (_shakeTimeLeft / _shakeTotalTime).clamp(0.0, 1.0)
        : 0.0;
    if (magnitude < remainingMag) return;
    _shakeMagnitude = magnitude;
    _shakeTimeLeft = seconds;
    _shakeTotalTime = seconds;
  }

  void _endGame(String reason) {
    if (gameOver.value) return;
    gameOverReason.value = reason;
    gameOver.value = true;
    overlays.add('gameOver');
    unawaited(_playEndMusic());
    unawaited(_submitRunResult());
  }

  Future<void> _submitRunResult() async {
    if (_submittedScore) return;
    _submittedScore = true;
    scoreSyncStatus.value = 'Submitting score...';

    const api = ScoreApi();
    try {
      await api.submitScore(
        login: tutorLogin,
        score: score.value,
        correctTigs: correctTigs.value,
        missedEvents: missedEvents.value,
        elapsedSeconds: elapsed.inSeconds,
        peakDifficulty: difficulty.value,
        missedNpcs: Map<String, int>.of(_missedEventsByLogin),
      );
      final results = await Future.wait([
        api.fetchLeaderboard(limit: 5),
        api.fetchSneakyNpcs(limit: 5),
      ]);
      bestScores.value = results[0] as List<LeaderboardEntry>;
      sneakyNpcs.value = results[1] as List<SneakyNpcEntry>;
      scoreSyncStatus.value = null;
    } catch (error) {
      scoreSyncStatus.value = 'Score server offline';
      debugPrint('Score sync failed: $error');
    }
  }

  Duration get elapsed => Duration(milliseconds: (_elapsed * 1000).round());

  bool _held(LogicalKeyboardKey a, LogicalKeyboardKey b) =>
      heldKeys.contains(a) || heldKeys.contains(b);

  void _updateCamera(double dt) {
    if (size.x <= 0 || size.y <= 0) return;

    final target = _tutor.position;
    final t = 1 - exp(-GameConfig.cameraFollowSmoothing * dt);
    final current = camera.viewfinder.position;
    final desired = current + (target - current) * t;

    // Clamp so the viewport doesn't show past the room edges. If the
    // viewport is bigger than the room on an axis, center that axis.
    final zoom = camera.viewfinder.zoom;
    final halfW = size.x / (2 * zoom);
    final halfH = size.y / (2 * zoom);
    final minX = halfW;
    final maxX = GameConfig.roomWidth + GameConfig.rightSceneryWidth - halfW;
    final minY = halfH;
    final maxY = GameConfig.roomHeight - halfH;

    final clamped = Vector2(
      minX <= maxX ? desired.x.clamp(minX, maxX) : GameConfig.roomWidth / 2,
      minY <= maxY ? desired.y.clamp(minY, maxY) : GameConfig.roomHeight / 2,
    );

    // Screen shake: decays linearly over its duration. Random direction
    // each frame so it reads as an impact, not a slide. Applied AFTER
    // clamping so the shake reads even against a wall.
    if (_shakeTimeLeft > 0 && _shakeTotalTime > 0) {
      _shakeTimeLeft = (_shakeTimeLeft - dt).clamp(0.0, _shakeTotalTime);
      final remaining = (_shakeTimeLeft / _shakeTotalTime).clamp(0.0, 1.0);
      final mag = _shakeMagnitude * remaining;
      final angle = _random.nextDouble() * 2 * pi;
      clamped.add(Vector2(cos(angle) * mag, sin(angle) * mag));
      if (_shakeTimeLeft <= 0) {
        _shakeMagnitude = 0;
        _shakeTotalTime = 0;
      }
    }

    camera.viewfinder.position = clamped;
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
    // Only one student should be physically using the corridor at a time
    // (to avoid pile-ups at the gate), so we gate "send home" on whether
    // someone is already leaving. Spawn already has its own _spawningStudent
    // mutex, so we don't gate it on broader transitions — that previously
    // starved spawning whenever any student wandered.
    final hasLeavingStudent = _students.any((s) => s.isLeavingCluster);

    for (final student in List<StudentNpc>.of(_students)) {
      if (student.hasExitedCluster ||
          student.isLeavingCluster ||
          !student.isSeated) {
        continue;
      }
      final remaining =
          (_studentStayTimers[student] ?? _randomStaySeconds()) - dt;
      _studentStayTimers[student] = remaining;
      if (remaining <= 0 && !hasLeavingStudent) {
        _sendStudentHome(student);
        break;
      }
    }

    if (_spawningStudent || _studentLoginQueue.isEmpty) return;
    if (_students.length >= _populationTargetCount) return;

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

/// Shape of a screen-flash effect.
///
/// - [uniform]: flat full-screen tint.
/// - [vignette]: transparent center → tint at the edges. Reads as
///   "damage closing in from the periphery." Used for misses.
/// - [burst]: tint at the center → transparent at the edges. Reads as
///   "energy releasing outward." Used for successful captures, so the
///   visual is the literal inverse of a miss.
enum FlashShape { uniform, vignette, burst }

/// Parameters for a single screen-flash effect. Read from [TutorSimGame]
/// by the HUD's `_FlashOverlay` whenever `flashTick` changes.
class FlashSignal {
  const FlashSignal({
    required this.color,
    this.peakAlpha = 0.45,
    this.durationMs = 250,
    this.shape = FlashShape.uniform,
    this.vignetteInnerStop = 0.4,
  });

  final Color color;
  final double peakAlpha;
  final int durationMs;
  final FlashShape shape;

  /// For [FlashShape.vignette]: radial-gradient stop where the tint
  /// starts. Higher = thinner ring of colour at the edges. Ignored for
  /// other shapes.
  final double vignetteInnerStop;
}
