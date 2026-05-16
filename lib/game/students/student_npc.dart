import 'package:flame/components.dart';

import '../game_config.dart';
import '../name_tag.dart';
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

    await add(
      SpriteComponent(
        sprite: CharacterSprites.character(row, direction: direction),
        size: size,
        paint: CharacterSprites.pixelPaint(),
      ),
    );

    await add(
      NameTag(text: login, position: Vector2(GameConfig.studentRadius, -4)),
    );
  }
}
