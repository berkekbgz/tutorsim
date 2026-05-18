import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flame/components.dart';

import '../game_config.dart';
import '../students/student_npc.dart';
import '../students/student_personality.dart';
import '../tutor_sim_game.dart';
import 'event_catalog.dart';
import 'event_mark_indicator.dart';

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

    // Fire the about-to-expire alarm once per event, ~1.5s before it would
    // miss. Tracked here (rather than inside each event class) so all event
    // types share the same warning behavior.
    for (final active in _activeEvents) {
      active.elapsed += dt;
      if (!active.warned &&
          active.elapsed >=
              active.visibleSeconds -
                  GameConfig.eventExpiryWarningLeadSeconds) {
        active.warned = true;
        // Stash the alarm stop function so the manager can cut it off if the
        // player captures (or the event is cancelled) before the clip
        // finishes — otherwise a beep keeps ringing after the event is
        // already resolved.
        unawaited(
          game.notifyEventAboutToExpire().then((stopAlarm) {
            if (stopAlarm == null) return;
            if (active.captured || active.event.isRemoved) {
              unawaited(stopAlarm());
            } else {
              active.alarmStop = stopAlarm;
            }
          }),
        );
      }
    }

    if (_activeEvents.length >= _currentMaxActiveEvents()) return;

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
    final built = _buildRandomEvent(
      spot,
      student: student,
      onExpired: () {
        mark.removeFromParent();
        // Distinguish "player captured this" from "ran out of time".
        // captureNearest sets `captured = true` before removing.
        if (!active.captured) game.notifyMissedEvent(active.student);
        _activeEvents.remove(active);
      },
    );
    active = _ActiveGameEvent(
      event: built.event,
      kindId: built.kindId,
      visibleSeconds: built.visibleSeconds,
      seatIndex: seatIndex,
      student: student,
      mark: mark,
    );
    _activeEvents.add(active);
    game.world.add(built.event);
    game.notifyDeskEventStarted();
    unawaited(student.sayEventStarted());
  }

  _BuiltEvent _buildRandomEvent(
    Vector2 spot, {
    required StudentNpc student,
    required void Function() onExpired,
  }) {
    final personality = student.personality;
    final difficulty = game.difficulty.value;

    // Visible window shrinks with difficulty (softer ramp than spawn rate
    // so events don't expire faster than the player can react). Clamped
    // so it never goes below a humane minimum.
    final baseVisible =
        GameConfig.bottleEventVisibleSeconds *
        personality.eventDurationMultiplier;
    final visible = (baseVisible / sqrt(difficulty)).clamp(
      GameConfig.bottleEventVisibleSecondsMin,
      GameConfig.bottleEventVisibleSeconds *
          personality.eventDurationMultiplier,
    );

    final kinds = EventCatalog.all;
    final weights = [for (final k in kinds) k.weightFor(personality)];
    final totalWeight = weights.fold<double>(0, (sum, w) => sum + w);
    var cursor = _random.nextDouble() * totalWeight;
    StudentEventKind chosen = kinds.last;
    for (int i = 0; i < kinds.length; i++) {
      cursor -= weights[i];
      if (cursor <= 0) {
        chosen = kinds[i];
        break;
      }
    }
    // Sleep zzz reads as a thought-bubble over the NPC, not as a prop
    // on the desk, so it ignores the desk-side event spot and anchors
    // to the right of the seated NPC's head instead. Other event kinds
    // still use the spot tied to their desk screen.
    final position = chosen.id == 'sleep'
        ? _sleepIndicatorPosition(student)
        : spot.clone();

    final event = chosen.build(
      position: position,
      visibleSeconds: visible,
      onExpired: onExpired,
    );
    return _BuiltEvent(
      event: event,
      kindId: chosen.id,
      visibleSeconds: visible,
    );
  }

  Vector2 _sleepIndicatorPosition(StudentNpc student) {
    // The eeping sprite is 24×24, centered. Offset it so its left edge
    // sits just past the NPC's right shoulder and its center is at
    // roughly head height (upper portion of the 32×32 NPC sprite).
    const indicatorHalfWidth = 12.0;
    const horizontalGap = 2.0;
    const headLift = GameConfig.studentRadius / 2;
    return student.position +
        Vector2(
          GameConfig.studentRadius + indicatorHalfWidth + horizontalGap,
          -headLift,
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
        // Treat as captured so the expiry callback doesn't penalize the
        // player — the event vanished because the student left, not
        // because the player ignored it.
        active.captured = true;
        active.stopAlarm();
        active.event.removeFromParent();
        active.mark?.removeFromParent();
        _activeEvents.remove(active);
      }
    }
  }

  EventCapture? captureNearest(Vector2 position) {
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

    nearest.captured = true;
    nearest.stopAlarm();
    _activeEvents.remove(nearest);
    nearest.event.removeFromParent();
    nearest.mark?.removeFromParent();
    return EventCapture(student: nearest.student, kindId: nearest.kindId);
  }

  double _randomInterval() {
    final difficulty = game.difficulty.value;
    final range = GameConfig.eventIntervalMax - GameConfig.eventIntervalMin;
    final base = GameConfig.eventIntervalMin + _random.nextDouble() * range;
    return base / difficulty;
  }

  int _currentMaxActiveEvents() {
    final difficulty = game.difficulty.value;
    final ramped = GameConfig.maxActiveEvents + (difficulty - 1).floor();
    return ramped.clamp(
      GameConfig.maxActiveEvents,
      GameConfig.maxActiveEventsCeiling,
    );
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
    required this.kindId,
    required this.visibleSeconds,
    required this.seatIndex,
    required this.student,
    this.mark,
  });

  final PositionComponent event;
  final String kindId;
  final double visibleSeconds;
  final int seatIndex;
  final StudentNpc? student;
  final EventMarkIndicator? mark;
  bool captured = false;
  double elapsed = 0;
  bool warned = false;
  StopFunction? alarmStop;

  void stopAlarm() {
    final stop = alarmStop;
    alarmStop = null;
    if (stop == null) return;
    unawaited(stop());
  }
}

class _BuiltEvent {
  const _BuiltEvent({
    required this.event,
    required this.kindId,
    required this.visibleSeconds,
  });

  final PositionComponent event;
  final String kindId;
  final double visibleSeconds;
}

class EventCapture {
  const EventCapture({required this.student, required this.kindId});

  final StudentNpc? student;
  final String kindId;
}
