import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../game_config.dart';
import '../name_tag.dart';
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
  late final NameTag _loginLabel;
  late final Map<CharacterDirection, SpriteAnimation> _idleAnims;
  late final Map<CharacterDirection, SpriteAnimation> _walkAnims;
  CharacterDirection _facing = CharacterDirection.down;

  static final Paint _shadowPaint = Paint()
    ..color = const Color(0x77000000)
    ..filterQuality = FilterQuality.none;
  static final Paint _bodyPaint = Paint()
    ..color = const Color(0xFF42D7F5)
    ..filterQuality = FilterQuality.none;
  static final Paint _bodyEdgePaint = Paint()
    ..color = const Color(0xFF07151A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..filterQuality = FilterQuality.none;

  @override
  void render(Canvas canvas) {
    _renderBody(canvas);
    super.render(canvas);
  }

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

    _loginLabel = NameTag(
      text: '',
      position: Vector2(GameConfig.tutorRadius, -4),
    );
    await add(_loginLabel);
  }

  void setLogin(String login) {
    _loginLabel.text = login;
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

    position = room.moveCircle(
      position,
      _input * GameConfig.tutorSpeed * dt,
      GameConfig.tutorRadius,
    );
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

  void _renderBody(Canvas canvas) {
    canvas.drawOval(Rect.fromLTWH(6, 23, 20, 8), _shadowPaint);

    final torso = RRect.fromRectAndRadius(
      Rect.fromLTWH(7, 11, 18, 16),
      const Radius.circular(3),
    );
    canvas.drawRRect(torso, _bodyPaint);
    canvas.drawRRect(torso, _bodyEdgePaint);

    canvas.drawRect(Rect.fromLTWH(6, 16, 5, 9), _bodyPaint);
    canvas.drawRect(Rect.fromLTWH(21, 16, 5, 9), _bodyPaint);
  }
}
