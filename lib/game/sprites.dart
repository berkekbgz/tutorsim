import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

enum CharacterDirection { left, down, up, right }

/// Character sprites from Kenney's RPG Urban Pack (CC0).
/// The atlas is 27 cols × 18 rows of 16×16 tiles. Each character uses
/// three rows of walk frames and four direction columns.
class CharacterSprites {
  CharacterSprites._();

  static const int tileSize = 16;
  static const Map<CharacterDirection, int> _directionCols = {
    CharacterDirection.left: 23,
    CharacterDirection.down: 24,
    CharacterDirection.up: 25,
    CharacterDirection.right: 26,
  };
  static const String _atlasAsset = 'tilemap_packed.png';

  /// Base row indices for characters. Row 0 is the tutor; the rest are
  /// distributed across the student NPCs.
  static const List<int> rows = [0, 3, 6, 9, 12, 15];

  static late Image _atlas;
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    _atlas = await Flame.images.load(_atlasAsset);
    _loaded = true;
  }

  /// Sprite for the character at [row] and [direction]. [frame] picks the pose:
  ///   0 = standing / idle
  ///   1 = left-foot step
  ///   2 = right-foot step
  static Sprite character(
    int row, {
    int frame = 0,
    CharacterDirection direction = CharacterDirection.down,
  }) {
    return Sprite(
      _atlas,
      srcPosition: Vector2(
        _directionCols[direction]! * tileSize.toDouble(),
        (row + frame) * tileSize.toDouble(),
      ),
      srcSize: Vector2.all(tileSize.toDouble()),
    );
  }

  static Sprite frontFacing(int row) {
    return Sprite(
      _atlas,
      srcPosition: Vector2(24 * tileSize.toDouble(), row * tileSize.toDouble()),
      srcSize: Vector2.all(tileSize.toDouble()),
    );
  }

  /// Walk cycle for a row's character. The standing frame is intentionally
  /// excluded so moving characters do not flash back to idle mid-step.
  static SpriteAnimation walkAnimation(
    int row, {
    CharacterDirection direction = CharacterDirection.down,
    double stepTime = 0.12,
  }) {
    return SpriteAnimation.spriteList([
      character(row, frame: 1, direction: direction),
      character(row, frame: 2, direction: direction),
    ], stepTime: stepTime);
  }

  /// Single-frame "animation" used for the idle pose.
  static SpriteAnimation idleAnimation(
    int row, {
    CharacterDirection direction = CharacterDirection.down,
  }) {
    return SpriteAnimation.spriteList(
      [character(row, frame: 0, direction: direction)],
      stepTime: 1,
      loop: false,
    );
  }

  /// Pixel-perfect paint for sprite rendering (nearest-neighbour).
  static Paint pixelPaint() => Paint()..filterQuality = FilterQuality.none;
}
