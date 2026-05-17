import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

class SpeechBubble extends PositionComponent {
  SpeechBubble({required String text, required Vector2 position})
    : _text = TextComponent(
        text: text,
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFF111111),
            fontFamily: 'PressStart2P',
            fontSize: 6,
            height: 1.4,
          ),
        ),
      ),
      super(position: position, anchor: Anchor.bottomCenter, priority: 30);

  final TextComponent _text;
  double _lifeLeft = 2.2;
  double _fade = 1;

  static final Paint _fillPaint = Paint()..color = const Color(0xFFF8F4DE);
  static final Paint _borderPaint = Paint()
    ..color = const Color(0xFF111111)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  Future<void> onLoad() async {
    await add(_text);
    size = Vector2(_text.width + 14, _text.height + 10);
    _text.position = Vector2(size.x / 2, size.y / 2 - 1);
  }

  @override
  void update(double dt) {
    super.update(dt);

    _lifeLeft -= dt;
    if (_lifeLeft <= 0) {
      removeFromParent();
      return;
    }
    _fade = _lifeLeft < 0.35 ? _lifeLeft / 0.35 : 1;
  }

  @override
  void render(Canvas canvas) {
    final alpha = (_fade * 255).round().clamp(0, 255);
    _fillPaint.color = Color.fromARGB(alpha, 248, 244, 222);
    _borderPaint.color = Color.fromARGB(alpha, 17, 17, 17);

    final body = Rect.fromLTWH(0, 0, size.x, size.y - 6);
    canvas.drawRect(body, _fillPaint);
    canvas.drawRect(body, _borderPaint);

    final tail = Path()
      ..moveTo(size.x / 2 - 6, size.y - 6)
      ..lineTo(size.x / 2, size.y)
      ..lineTo(size.x / 2 + 6, size.y - 6)
      ..close();
    canvas.drawPath(tail, _fillPaint);
    canvas.drawPath(tail, _borderPaint);
  }
}
