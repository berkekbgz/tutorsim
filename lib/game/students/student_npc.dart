import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../game_config.dart';
import '../sprites.dart';

class StudentNpc extends PositionComponent {
  StudentNpc({
    required this.login,
    required Vector2 position,
    required this.direction,
  }) : super(
         position: position,
         size: Vector2.all(GameConfig.studentRadius * 2),
         anchor: Anchor.center,
         priority: 5,
       );

  final String login;
  final CharacterDirection direction;

  @override
  Future<void> onLoad() async {
    // Pick a character deterministically per login so the same student
    // always wears the same outfit between sessions. Skip the tutor row.
    final pool = CharacterSprites.rows
        .where((r) => r != GameConfig.tutorCharacterRow)
        .toList();
    final row = pool[login.hashCode.abs() % pool.length];

    print(
      "${login} : character row $row , position $position",
    ); // Debug log to verify deterministic character assignment and correct seating positions.
    await add(
      SpriteComponent(
        sprite: CharacterSprites.character(row, direction: direction),
        size: size,
        paint: CharacterSprites.pixelPaint(),
      ),
    );

    // Login label floats above the head.
    await add(
      TextComponent(
        text: login,
        anchor: Anchor.bottomCenter,
        position: Vector2(GameConfig.studentRadius, -4),
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                blurRadius: 2,
                color: Color(0xCC000000),
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
