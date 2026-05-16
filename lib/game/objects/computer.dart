import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/painting.dart';

import '../game_config.dart';

class Computer extends PositionComponent {
  Computer({
    required Vector2 position,
    this.facingBack = false,
    this.scrolling = false,
  }) : super(
         position: position,
         size: Vector2(GameConfig.computerWidth, GameConfig.computerHeight),
       );

  final bool facingBack;
  final bool scrolling;

  @override
  Future<void> onLoad() async {
    if (scrolling && !facingBack) {
      final frames = await Flame.images.loadAll([
        for (int i = 1; i <= 8; i++) 'computer-scrolling$i.png',
      ]);
      await add(
        SpriteAnimationComponent(
          animation: SpriteAnimation.spriteList(
            frames.map(Sprite.new).toList(),
            stepTime: 0.12,
          ),
          size: size,
          paint: _pixelPaint(),
        ),
      );
      return;
    }

    await add(
      SpriteComponent(
        sprite: Sprite(
          await Flame.images.load(
            facingBack ? 'computer-back.png' : 'computer.png',
          ),
        ),
        size: size,
        paint: _pixelPaint(),
      ),
    );
  }

  Paint _pixelPaint() => Paint()..filterQuality = FilterQuality.none;
}
