import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

class NameTag extends PositionComponent {
  NameTag({required String text, required Vector2 position})
    : _text = TextComponent(
        text: text,
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontFamily: 'PressStart2P',
            fontSize: 7,
            fontWeight: FontWeight.w700,
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
      super(position: position, anchor: Anchor.bottomCenter, priority: 20);

  final TextComponent _text;

  static final Paint _backgroundPaint = Paint()
    ..color = const Color(0x99000000);

  set text(String value) {
    _text.text = value;
    _resizeToText();
  }

  @override
  Future<void> onLoad() async {
    await add(_text);
    _resizeToText();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), _backgroundPaint);
  }

  void _resizeToText() {
    size = Vector2(_text.width + 8, _text.height + 4);
    _text.position = size / 2;
  }
}
