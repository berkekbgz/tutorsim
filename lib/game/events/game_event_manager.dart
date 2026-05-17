import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';

import '../game_config.dart';
import '../students/student_npc.dart';
import '../students/student_personality.dart';
import '../tutor_sim_game.dart';
import 'event_mark_indicator.dart';
import 'types/bottle_drop_event.dart';
import 'types/coffee_put_event.dart';

class GameEventManager extends Component {
  GameEventManager(this.game);

  final TutorSimGame game;
  final Random _random = Random();
  final List<_ActiveGameEvent> _activeEvents = [];

  double _nextEventIn = GameConfig.firstEventDelay;

  @override
  void update(double dt) {
    super.update(dt);

    _cancelEventsForStudentsWhoLeftSeats();
    _activeEvents.removeWhere((active) => active.event.isRemoved);
    if (_activeEvents.length >= GameConfig.maxActiveEvents) return;

    _nextEventIn -= dt;
    if (_nextEventIn > 0) return;

    _triggerRandomEvent();
    _nextEventIn = _randomInterval();
  }

  void _triggerRandomEvent() {
    if (game.room.eventSpots.isEmpty) return;

    final eligibleSpots = <_EligibleEventSpot>[];
    for (int i = 0; i < game.room.eventSpots.length; i++) {
      final seatIndex = game.room.eventSeatIndices[i];
      final seatAlreadyHasEvent = _activeEvents.any(
        (active) => active.seatIndex == seatIndex,
      );
      final student = game.studentAtSeat(seatIndex);
      if (!seatAlreadyHasEvent && student != null) {
        eligibleSpots.add(
          _EligibleEventSpot(
            spotIndex: i,
            student: student,
            weight: student.personality.eventWeightMultiplier,
          ),
        );
      }
    }
    if (eligibleSpots.isEmpty) return;

    final eligibleSpot = _pickWeightedSpot(eligibleSpots);
    final spotIndex = eligibleSpot.spotIndex;
    final spot = game.room.eventSpots[spotIndex];
    final seatIndex = game.room.eventSeatIndices[spotIndex];
    final student = eligibleSpot.student;
    final mark = EventMarkIndicator(game: game, target: student);
    game.world.add(mark);

    late final _ActiveGameEvent active;
    final event = _buildRandomEvent(
      spot,
      student: student,
      onExpired: () {
        mark.removeFromParent();
        _activeEvents.remove(active);
      },
    );
    active = _ActiveGameEvent(
      event: event,
      seatIndex: seatIndex,
      student: student,
      mark: mark,
    );
    _activeEvents.add(active);
    game.world.add(event);
    unawaited(student.sayEventStarted());
  }

  PositionComponent _buildRandomEvent(
    Vector2 spot, {
    required StudentNpc student,
    required void Function() onExpired,
  }) {
    final personality = student.personality;
    final coffeeWeight = personality.coffeeEventWeight;
    final bottleWeight = personality.bottleEventWeight;
    final duration =
        GameConfig.bottleEventVisibleSeconds *
        personality.eventDurationMultiplier;

    if (_random.nextDouble() * (coffeeWeight + bottleWeight) < coffeeWeight) {
      return CoffeePutEvent(
        position: spot.clone(),
        visibleSeconds: duration,
        onExpired: onExpired,
      );
    }

    return BottleDropEvent(
      position: spot.clone(),
      visibleSeconds: duration,
      onExpired: onExpired,
    );
  }

  _EligibleEventSpot _pickWeightedSpot(List<_EligibleEventSpot> spots) {
    final totalWeight = spots.fold<double>(0, (sum, spot) => sum + spot.weight);
    var cursor = _random.nextDouble() * totalWeight;
    for (final spot in spots) {
      cursor -= spot.weight;
      if (cursor <= 0) return spot;
    }

    return spots.last;
  }

  void _cancelEventsForStudentsWhoLeftSeats() {
    for (final active in List<_ActiveGameEvent>.of(_activeEvents)) {
      final student = active.student;
      if (student == null ||
          student.currentSeatIndex != active.seatIndex ||
          !student.isSeated) {
        active.event.removeFromParent();
        active.mark?.removeFromParent();
        _activeEvents.remove(active);
      }
    }
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

class _EligibleEventSpot {
  const _EligibleEventSpot({
    required this.spotIndex,
    required this.student,
    required this.weight,
  });

  final int spotIndex;
  final StudentNpc student;
  final double weight;
}

class _ActiveGameEvent {
  _ActiveGameEvent({
    required this.event,
    required this.seatIndex,
    required this.student,
    this.mark,
  });

  final PositionComponent event;
  final int seatIndex;
  final StudentNpc? student;
  final EventMarkIndicator? mark;
}
