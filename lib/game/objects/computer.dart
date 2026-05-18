import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/painting.dart';

import '../game_config.dart';

class Computer extends PositionComponent {
  Computer({required Vector2 position, this.facingBack = false})
    : super(
        position: position,
        size: Vector2(GameConfig.computerWidth, GameConfig.computerHeight),
      );

  /// Back-facing computers (the ones whose screen the player can't see)
  /// stay static — there's nothing to animate. Front-facing computers
  /// cycle between an idle screen and a scrolling-text animation on
  /// their own randomised schedule to keep the periphery busy.
  final bool facingBack;

  // Cycle timing. Steady-state ratio (~3s scrolling : ~11s idle) means
  // each front computer is scrolling ~21% of the time. Across 16 front
  // computers that averages ~3 simultaneously scrolling at any moment,
  // matching the previous hard-coded behaviour but with random churn.
  static const double _scrollMinSeconds = 2.0;
  static const double _scrollMaxSeconds = 5.0;
  static const double _idleMinSeconds = 7.0;
  static const double _idleMaxSeconds = 15.0;
  static const double _initialScrollChance = 0.21;

  static final Random _random = Random();

  SpriteAnimation? _idleAnimation;
  SpriteAnimation? _scrollAnimation;
  SpriteAnimationComponent? _display;
  bool _scrolling = false;
  double _stateTimeLeft = 0;

  @override
  Future<void> onLoad() async {
    if (facingBack) {
      final back = await Flame.images.load('computer-back.png');
      await add(
        SpriteComponent(
          sprite: Sprite(back),
          size: size,
          paint: _pixelPaint(),
        ),
      );
      return;
    }

    final idleImage = await Flame.images.load('computer.png');
    // Single-sprite "animation" with a giant step so it never advances —
    // lets us reuse one SpriteAnimationComponent for both states and
    // just swap the animation property to toggle scrolling on/off.
    _idleAnimation = SpriteAnimation.spriteList(
      [Sprite(idleImage)],
      stepTime: 1e9,
      loop: false,
    );

    final frames = await Flame.images.loadAll([
      for (int i = 1; i <= 8; i++) 'computer-scrolling$i.png',
    ]);
    _scrollAnimation = SpriteAnimation.spriteList(
      frames.map(Sprite.new).toList(),
      stepTime: 0.12,
    );

    _scrolling = _random.nextDouble() < _initialScrollChance;
    _display = SpriteAnimationComponent(
      animation: _scrolling ? _scrollAnimation : _idleAnimation,
      size: size,
      paint: _pixelPaint(),
    );
    await add(_display!);

    // Stagger so computers don't all swap at the same moment.
    _stateTimeLeft = _random.nextDouble() *
        (_scrolling ? _scrollMaxSeconds : _idleMaxSeconds);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final display = _display;
    if (display == null) return;

    _stateTimeLeft -= dt;
    if (_stateTimeLeft > 0) return;

    _scrolling = !_scrolling;
    display.animation = _scrolling ? _scrollAnimation : _idleAnimation;
    _stateTimeLeft = _scrolling
        ? _randomRange(_scrollMinSeconds, _scrollMaxSeconds)
        : _randomRange(_idleMinSeconds, _idleMaxSeconds);
  }

  double _randomRange(double min, double max) {
    return min + _random.nextDouble() * (max - min);
  }

  Paint _pixelPaint() => Paint()..filterQuality = FilterQuality.none;
}
