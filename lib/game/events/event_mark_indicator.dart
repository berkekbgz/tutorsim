import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import '../game_config.dart';
import '../sprites.dart';
import '../tutor_sim_game.dart';

class EventMarkIndicator extends SpriteComponent {
  EventMarkIndicator({required this.game, required this.target})
    : super(
        size: Vector2.all(64),
        anchor: Anchor.bottomCenter,
        priority: 100,
        paint: CharacterSprites.pixelPaint(),
      );

  final TutorSimGame game;
  final PositionComponent target;

  @override
  Future<void> onLoad() async {
    sprite = Sprite(await Flame.images.load('mark.png'));
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (target.isRemoved) {
      removeFromParent();
      return;
    }

    final targetHead =
        target.position + Vector2(0, -GameConfig.studentRadius - 12);
    final visible = _visibleWorldRect();

    if (visible.contains(Offset(targetHead.x, targetHead.y))) {
      position = targetHead;
      return;
    }

    const padding = 8.0;
    position = Vector2(
      targetHead.x.clamp(
        visible.left + padding + size.x / 2,
        visible.right - padding - size.x / 2,
      ),
      targetHead.y.clamp(
        visible.top + padding + size.y,
        visible.bottom - padding,
      ),
    );
  }

  Rect _visibleWorldRect() {
    final zoom = game.camera.viewfinder.zoom;
    final center = game.camera.viewfinder.position;
    final worldSize = game.size / zoom;

    return Rect.fromCenter(
      center: Offset(center.x, center.y),
      width: worldSize.x,
      height: worldSize.y,
    );
  }
}
