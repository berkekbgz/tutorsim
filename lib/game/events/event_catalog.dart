import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../students/student_personality.dart';
import 'types/bottle_drop_event.dart';
import 'types/coffee_put_event.dart';

/// Signature every event type's constructor wrapper must satisfy.
typedef EventBuilder =
    PositionComponent Function({
      required Vector2 position,
      required double visibleSeconds,
      required VoidCallback onExpired,
    });

/// One entry in the registry: how often it shows up for a given
/// personality, and how to build it on demand.
class StudentEventKind {
  const StudentEventKind({
    required this.id,
    required this.weightFor,
    required this.build,
  });

  final String id;
  final double Function(StudentPersonality personality) weightFor;
  final EventBuilder build;
}

/// Add new event types here. The manager weighs them per-personality
/// and picks one at spawn time. Each new entry needs a personality
/// weight getter (see [StudentPersonalityTuning]) and a class with a
/// constructor matching [EventBuilder].
class EventCatalog {
  EventCatalog._();

  static final List<StudentEventKind> all = [
    StudentEventKind(
      id: 'bottle',
      weightFor: (p) => p.bottleEventWeight,
      build:
          ({
            required Vector2 position,
            required double visibleSeconds,
            required VoidCallback onExpired,
          }) => BottleDropEvent(
            position: position,
            visibleSeconds: visibleSeconds,
            onExpired: onExpired,
          ),
    ),
    StudentEventKind(
      id: 'coffee',
      weightFor: (p) => p.coffeeEventWeight,
      build:
          ({
            required Vector2 position,
            required double visibleSeconds,
            required VoidCallback onExpired,
          }) => CoffeePutEvent(
            position: position,
            visibleSeconds: visibleSeconds,
            onExpired: onExpired,
          ),
    ),
  ];
}
