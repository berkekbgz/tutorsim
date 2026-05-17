import 'dart:math';

import 'package:flame/components.dart';

import '../game_config.dart';
import '../name_tag.dart';
import '../sprites.dart';

class StudentSeatAssignment {
  const StudentSeatAssignment({
    required this.index,
    required this.position,
    required this.direction,
  });

  final int index;
  final Vector2 position;
  final CharacterDirection direction;
}

class StudentNpc extends PositionComponent {
  StudentNpc({
    required this.login,
    required Vector2 position,
    required CharacterDirection direction,
    required this.currentSeatIndex,
    required this.findPath,
    required this.randomWalkablePoint,
    required this.releaseSeat,
    required this.requestSeat,
  }) : seatPosition = position.clone(),
       seatDirection = direction,
       super(
         position: position,
         size: Vector2.all(GameConfig.studentRadius * 2),
         anchor: Anchor.center,
         priority: 5,
       );

  final String login;
  final List<Vector2> Function(Vector2 start, Vector2 goal, double radius)
  findPath;
  final Vector2 Function(Random random, double radius) randomWalkablePoint;
  final void Function(StudentNpc student) releaseSeat;
  final StudentSeatAssignment? Function(StudentNpc student) requestSeat;
  final Random _random = Random();

  int? currentSeatIndex;
  Vector2 seatPosition;
  CharacterDirection seatDirection;

  late final SpriteAnimationComponent _sprite;
  late final Map<CharacterDirection, SpriteAnimation> _idleAnimations;
  late final Map<CharacterDirection, SpriteAnimation> _walkAnimations;
  CharacterDirection _facing = CharacterDirection.down;
  final List<Vector2> _path = [];
  Vector2? _moveTarget;
  StudentSeatAssignment? _destinationSeat;
  double _pauseLeft = 0;

  bool get isSeated {
    return currentSeatIndex != null &&
        _moveTarget == null &&
        _pauseLeft <= 0 &&
        position.distanceToSquared(seatPosition) < 4;
  }

  @override
  Future<void> onLoad() async {
    // Pick a character deterministically per login so the same student
    // always wears the same outfit between sessions. Skip the tutor row.
    final pool = CharacterSprites.rows
        .where((r) => r != GameConfig.tutorCharacterRow)
        .toList();
    final row = pool[login.hashCode.abs() % pool.length];
    _facing = seatDirection;
    _idleAnimations = {
      for (final direction in CharacterDirection.values)
        direction: CharacterSprites.idleAnimation(row, direction: direction),
    };
    _walkAnimations = {
      for (final direction in CharacterDirection.values)
        direction: CharacterSprites.walkAnimation(row, direction: direction),
    };

    await add(
      _sprite = SpriteAnimationComponent(
        animation: _idleAnimations[_facing],
        size: size,
        paint: CharacterSprites.pixelPaint(),
        playing: false,
      ),
    );

    await add(
      NameTag(text: login, position: Vector2(GameConfig.studentRadius, -4)),
    );
  }

  // Kept as a safe no-op so stale hot-reload code cannot crash if it still
  // calls the old NPC-local event mark API. Event marks now live in world space.
  Future<void> showEventMark() async {}

  void hideEventMark() {}

  @override
  void update(double dt) {
    super.update(dt);

    if (_moveTarget != null) {
      _stepTowardTarget(dt);
      return;
    }

    if (_pauseLeft > 0) {
      _pauseLeft -= dt;
      if (_pauseLeft <= 0) {
        _pathToOpenSeat();
      }
      return;
    }

    if (currentSeatIndex == null) {
      _pathToOpenSeat();
      return;
    }

    if (isSeated &&
        _random.nextDouble() < GameConfig.studentWanderChancePerSecond * dt) {
      final target = randomWalkablePoint(_random, GameConfig.studentRadius);
      if (_startPathTo(target)) _leaveSeat();
    }
  }

  void _stepTowardTarget(double dt) {
    final target = _moveTarget!;
    final delta = target - position;
    final distance = delta.length;
    if (distance <= GameConfig.studentWalkSpeed * dt) {
      position = target;
      _moveTarget = _path.isEmpty ? null : _path.removeAt(0);
      if (_moveTarget != null) return;

      _setIdleAnimation();
      final destinationSeat = _destinationSeat;
      if (destinationSeat != null) {
        currentSeatIndex = destinationSeat.index;
        seatPosition = destinationSeat.position.clone();
        seatDirection = destinationSeat.direction;
        _destinationSeat = null;
        _setIdleAnimation();
      } else {
        _pauseLeft = _randomPause();
      }
      return;
    }

    final directionVector = delta / distance;
    position += directionVector * GameConfig.studentWalkSpeed * dt;
    _setWalkAnimation(_directionFor(directionVector));
  }

  bool _startPathTo(Vector2 target) {
    final nextPath = findPath(position, target, GameConfig.studentRadius);
    if (nextPath.isEmpty) return false;

    _path
      ..clear()
      ..addAll(nextPath);
    _moveTarget = _path.removeAt(0);
    return true;
  }

  void _leaveSeat() {
    if (currentSeatIndex == null) return;
    releaseSeat(this);
    currentSeatIndex = null;
  }

  void _pathToOpenSeat() {
    final assignment = requestSeat(this);
    if (assignment == null) return;

    _destinationSeat = assignment;
    if (!_startPathTo(assignment.position)) _destinationSeat = null;
  }

  double _randomPause() {
    final range =
        GameConfig.studentWanderPauseMax - GameConfig.studentWanderPauseMin;
    return GameConfig.studentWanderPauseMin + _random.nextDouble() * range;
  }

  CharacterDirection _directionFor(Vector2 input) {
    if (input.x.abs() >= input.y.abs()) {
      return input.x < 0 ? CharacterDirection.left : CharacterDirection.right;
    }
    return input.y < 0 ? CharacterDirection.up : CharacterDirection.down;
  }

  void _setWalkAnimation(CharacterDirection direction) {
    if (_facing == direction && _sprite.playing) return;
    _facing = direction;
    _sprite.animation = _walkAnimations[direction];
    _sprite.animationTicker?.reset();
    _sprite.playing = true;
  }

  void _setIdleAnimation() {
    final targetAnimation = _idleAnimations[seatDirection];
    if (_sprite.animation != targetAnimation) {
      _sprite.animation = targetAnimation;
      _sprite.animationTicker?.reset();
    }
    _facing = seatDirection;
    _sprite.playing = false;
  }
}
