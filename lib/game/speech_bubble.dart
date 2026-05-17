import 'package:flame/components.dart';
import 'package:flame/flame.dart';
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
  late final Sprite _bubbleSprite;
  double _lifeLeft = 2.2;
  double _fade = 1;
  final Paint _bubblePaint = Paint()..filterQuality = FilterQuality.none;

  @override
  Future<void> onLoad() async {
    _bubbleSprite = Sprite(await Flame.images.load('bubble.png'));
    await add(_text);
    size = Vector2(
      (_text.width + 18).clamp(42.0, 96.0),
      (_text.height + 18).clamp(24.0, 42.0),
    );
    _text.position = Vector2(size.x / 2, size.y / 2 - 5);
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
  void renderTree(Canvas canvas) {
    // Fade the entire subtree (bubble fill + border + text child) by
    // compositing through a transparency layer. This keeps the text in
    // sync with the bubble instead of fading only the background.
    if (_fade >= 1) {
      super.renderTree(canvas);
      return;
    }
    final alpha = (_fade * 255).round().clamp(0, 255);
    final layerPaint = Paint()..color = Color.fromARGB(alpha, 255, 255, 255);
    canvas.saveLayer(null, layerPaint);
    super.renderTree(canvas);
    canvas.restore();
  }

  @override
  void render(Canvas canvas) {
    _bubbleSprite.render(canvas, size: size, overridePaint: _bubblePaint);
  }
}
