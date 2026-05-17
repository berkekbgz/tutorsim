import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';

import '../../game_config.dart';
import '../../sprites.dart';

class CoffeePutEvent extends SpriteComponent {
  CoffeePutEvent({
    required Vector2 position,
    this.onExpired,
    double? visibleSeconds,
  }) : _lifeLeft = visibleSeconds ?? GameConfig.bottleEventVisibleSeconds,
       super(
         position: position,
         size: Vector2.all(28),
         anchor: Anchor.center,
         priority: 9,
         paint: CharacterSprites.pixelPaint(),
       );

  static const int _firstFrameNumber = 1;
  static const int _idleStartFrameNumber = 10;
  static const int _lastFrameNumber = 14;
  static const double _putStepTime = 0.08;
  static const double _idleStepTime = 0.16;

  final VoidCallback? onExpired;
  final List<Sprite> _frames = [];
  double _lifeLeft;
  double _frameTime = 0;
  int _frameIndex = 0;
  bool _idleLoop = false;
  bool _expired = false;

  int get _idleStartIndex => _idleStartFrameNumber - _firstFrameNumber;

  int get _lastIndex => _lastFrameNumber - _firstFrameNumber;

  @override
  Future<void> onLoad() async {
    final images = await Flame.images.loadAll([
      for (int i = _firstFrameNumber; i <= _lastFrameNumber; i++)
        'coffee$i.png',
    ]);
    _frames.addAll(images.map(Sprite.new));
    sprite = _frames.first;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _lifeLeft -= dt;
    if (_lifeLeft <= 0) {
      _expire();
      return;
    }
    if (_frames.isEmpty) return;

    _frameTime += dt;
    if (_idleLoop) {
      _advanceIdleLoop();
    } else {
      _advancePutAnimation();
    }
  }

  @override
  void onRemove() {
    _expire();
    super.onRemove();
  }

  void _advancePutAnimation() {
    while (_frameTime >= _putStepTime && !_idleLoop) {
      _frameTime -= _putStepTime;
      _frameIndex++;
      if (_frameIndex >= _idleStartIndex) {
        _frameIndex = _idleStartIndex;
        _idleLoop = true;
      }
      sprite = _frames[_frameIndex];
    }
  }

  void _advanceIdleLoop() {
    while (_frameTime >= _idleStepTime) {
      _frameTime -= _idleStepTime;
      _frameIndex++;
      if (_frameIndex > _lastIndex) _frameIndex = _idleStartIndex;
      sprite = _frames[_frameIndex];
    }
  }

  void _expire() {
    if (_expired) return;
    _expired = true;
    onExpired?.call();
    removeFromParent();
  }
}
