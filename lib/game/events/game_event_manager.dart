import 'dart:math';

import 'package:flame/components.dart';

import '../game_config.dart';
import '../students/student_npc.dart';
import '../tutor_sim_game.dart';
import 'event_mark_indicator.dart';
import 'types/bottle_drop_event.dart';

class GameEventManager extends Component {
  GameEventManager(this.game);

  final TutorSimGame game;
  final Random _random = Random();
  final List<_ActiveGameEvent> _activeEvents = [];

  double _nextEventIn = GameConfig.firstEventDelay;

  @override
  void update(double dt) {
    super.update(dt);

    _activeEvents.removeWhere((active) => active.event.isRemoved);
    if (_activeEvents.length >= GameConfig.maxActiveEvents) return;

    _nextEventIn -= dt;
    if (_nextEventIn > 0) return;

    _triggerRandomEvent();
    _nextEventIn = _randomInterval();
  }

  void _triggerRandomEvent() {
    if (game.room.eventSpots.isEmpty) return;

    final spotIndex = _random.nextInt(game.room.eventSpots.length);
    final spot = game.room.eventSpots[spotIndex];
    final seatIndex = game.room.eventSeatIndices[spotIndex];
    final student = game.studentAtSeat(seatIndex);
    final mark = student == null
        ? null
        : EventMarkIndicator(game: game, target: student);
    if (mark != null) game.world.add(mark);

    late final _ActiveGameEvent active;
    final event = BottleDropEvent(
      position: spot.clone(),
      onExpired: () {
        mark?.removeFromParent();
        _activeEvents.remove(active);
      },
    );
    active = _ActiveGameEvent(event: event, student: student, mark: mark);
    _activeEvents.add(active);
    game.world.add(event);
  }

  StudentNpc? captureNearest(Vector2 position) {
    _activeEvents.removeWhere((active) => active.event.isRemoved);
    if (_activeEvents.isEmpty) return null;

    _ActiveGameEvent? nearest;
    var nearestDistance2 = double.infinity;
    for (final active in _activeEvents) {
      final distance2 = active.event.position.distanceToSquared(position);
      if (distance2 < nearestDistance2) {
        nearest = active;
        nearestDistance2 = distance2;
      }
    }

    if (nearest == null ||
        nearestDistance2 >
            GameConfig.eventCaptureRadius * GameConfig.eventCaptureRadius) {
      return null;
    }

    nearest.event.removeFromParent();
    return nearest.student;
  }

  double _randomInterval() {
    final range = GameConfig.eventIntervalMax - GameConfig.eventIntervalMin;
    return GameConfig.eventIntervalMin + _random.nextDouble() * range;
  }
}

class _ActiveGameEvent {
  _ActiveGameEvent({required this.event, required this.student, this.mark});

  final BottleDropEvent event;
  final StudentNpc? student;
  final EventMarkIndicator? mark;
}
