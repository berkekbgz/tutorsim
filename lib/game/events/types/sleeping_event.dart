import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';

import '../../game_config.dart';
import '../../sprites.dart';

class SleepingEvent extends SpriteAnimationComponent {
  SleepingEvent({
    required Vector2 position,
    this.onExpired,
    double? visibleSeconds,
  }) : _lifeLeft = visibleSeconds ?? GameConfig.bottleEventVisibleSeconds,
       super(
         position: position,
         size: Vector2.all(24),
         anchor: Anchor.center,
         priority: 9,
         paint: CharacterSprites.pixelPaint(),
       );

  final VoidCallback? onExpired;
  double _lifeLeft;
  bool _expired = false;

  @override
  Future<void> onLoad() async {
    final frames = await Flame.images.loadAll([
      for (int i = 1; i <= 4; i++) 'eeping$i.png',
    ]);
    animation = SpriteAnimation.spriteList(
      frames.map(Sprite.new).toList(),
      stepTime: 0.28,
      loop: true,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    _lifeLeft -= dt;
    if (_lifeLeft <= 0) _expire();
  }

  @override
  void onRemove() {
    _expire();
    super.onRemove();
  }

  void _expire() {
    if (_expired) return;
    _expired = true;
    onExpired?.call();
    removeFromParent();
  }
}
