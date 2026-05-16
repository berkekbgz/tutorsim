import 'dart:math';

import 'package:flame/components.dart';

import '../game_config.dart';
import '../tutor_sim_game.dart';
import 'event_mark_indicator.dart';
import 'types/bottle_drop_event.dart';

class GameEventManager extends Component {
  GameEventManager(this.game);

  final TutorSimGame game;
  final Random _random = Random();
  final List<Component> _activeEvents = [];

  double _nextEventIn = GameConfig.firstEventDelay;

  @override
  void update(double dt) {
    super.update(dt);

    _activeEvents.removeWhere((event) => event.isRemoved);
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

    final event = BottleDropEvent(
      position: spot.clone(),
      onExpired: () => mark?.removeFromParent(),
    );
    _activeEvents.add(event);
    game.world.add(event);
  }

  double _randomInterval() {
    final range = GameConfig.eventIntervalMax - GameConfig.eventIntervalMin;
    return GameConfig.eventIntervalMin + _random.nextDouble() * range;
  }
}
