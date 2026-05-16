import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import '../game_config.dart';
import '../sprites.dart';
import '../world/cluster_room.dart';

/// The Tutor. Reads the live held-keys set every frame, so movement
/// and the walk/idle animation stay in sync with the player's input.
class TutorPlayer extends PositionComponent {
  TutorPlayer({
    required Vector2 position,
    required this.room,
    required this.heldKeys,
  }) : super(
         position: position,
         size: Vector2.all(GameConfig.tutorRadius * 2),
         anchor: Anchor.center,
         priority: 10,
       );

  final ClusterRoom room;

  /// Shared, mutable held-keys set maintained by main.dart's
  /// HardwareKeyboard event handler. We never replace it — we just read.
  final Set<LogicalKeyboardKey> heldKeys;

  final Vector2 _input = Vector2.zero();

  late final SpriteAnimationComponent _sprite;
  late final Map<CharacterDirection, SpriteAnimation> _idleAnims;
  late final Map<CharacterDirection, SpriteAnimation> _walkAnims;
  CharacterDirection _facing = CharacterDirection.down;

  @override
  Future<void> onLoad() async {
    final row = GameConfig.tutorCharacterRow;
    _idleAnims = {
      for (final direction in CharacterDirection.values)
        direction: CharacterSprites.idleAnimation(row, direction: direction),
    };
    _walkAnims = {
      for (final direction in CharacterDirection.values)
        direction: CharacterSprites.walkAnimation(row, direction: direction),
    };
    _sprite = SpriteAnimationComponent(
      animation: _idleAnims[_facing],
      size: size,
      paint: CharacterSprites.pixelPaint(),
      playing: false,
    );
    await add(_sprite);
  }

  @override
  void update(double dt) {
    super.update(dt);

    _readInput(heldKeys);
    final moving = _input.length2 > 0;
    if (moving) _facing = _directionFor(_input);

    final targetAnimation = moving ? _walkAnims[_facing] : _idleAnims[_facing];
    if (_sprite.animation != targetAnimation) {
      _sprite.animation = targetAnimation;
      _sprite.animationTicker?.reset();
    }
    _sprite.playing = moving;

    if (!moving) return;

    final step = _input * GameConfig.tutorSpeed * dt;
    final r = GameConfig.tutorRadius;
    final minX = r + GameConfig.wallThickness;
    final maxX = GameConfig.roomWidth - r - GameConfig.wallThickness;
    final minY = r + GameConfig.wallThickness;
    final maxY = GameConfig.roomHeight - r - GameConfig.wallThickness;

    // Try X and Y independently so we slide along walls/benches instead
    // of getting fully stuck on contact.
    final tryX = Vector2((position.x + step.x).clamp(minX, maxX), position.y);
    if (!room.isBlocked(tryX, r)) position.x = tryX.x;

    final tryY = Vector2(position.x, (position.y + step.y).clamp(minY, maxY));
    if (!room.isBlocked(tryY, r)) position.y = tryY.y;
  }

  void _readInput(Set<LogicalKeyboardKey> keys) {
    _input.setZero();
    if (keys.contains(LogicalKeyboardKey.keyW) ||
        keys.contains(LogicalKeyboardKey.arrowUp)) {
      _input.y -= 1;
    }
    if (keys.contains(LogicalKeyboardKey.keyS) ||
        keys.contains(LogicalKeyboardKey.arrowDown)) {
      _input.y += 1;
    }
    if (keys.contains(LogicalKeyboardKey.keyA) ||
        keys.contains(LogicalKeyboardKey.arrowLeft)) {
      _input.x -= 1;
    }
    if (keys.contains(LogicalKeyboardKey.keyD) ||
        keys.contains(LogicalKeyboardKey.arrowRight)) {
      _input.x += 1;
    }
    if (_input.length2 > 0) _input.normalize();
  }

  CharacterDirection _directionFor(Vector2 input) {
    if (input.x.abs() >= input.y.abs()) {
      return input.x < 0 ? CharacterDirection.left : CharacterDirection.right;
    }
    return input.y < 0 ? CharacterDirection.up : CharacterDirection.down;
  }
}
