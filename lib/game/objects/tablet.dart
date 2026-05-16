import 'dart:ui';

import 'package:flame/components.dart';

import '../game_config.dart';

class Tablet extends PositionComponent {
  Tablet({required Vector2 position})
      : super(
          position: position,
          size: Vector2(GameConfig.tabletWidth, GameConfig.tabletHeight),
        );

  static final _frame = Paint()..color = GameConfig.tabletColor;
  static final _screen = Paint()..color = GameConfig.tabletScreenColor;

  @override
  void render(Canvas canvas) {
    final outer = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, const Radius.circular(4)),
      _frame,
    );
    canvas.drawRect(
      Rect.fromLTWH(3, 3, size.x - 6, size.y - 6),
      _screen,
    );
  }
}
