import '../game_config.dart';
import '../world/cluster_room.dart';
import 'student_npc.dart';

/// Spawns the MVP student roster: one student per login from
/// [GameConfig.studentLogins], seated at the first N desks.
class StudentFactory {
  StudentFactory(this.room);

  final ClusterRoom room;

  List<StudentNpc> spawnAll() {
    final result = <StudentNpc>[];
    final logins = GameConfig.studentLogins;
    final count = logins.length < room.seats.length
        ? logins.length
        : room.seats.length;
    for (int i = 0; i < count; i++) {
      result.add(
        StudentNpc(
          login: logins[i],
          position: room.seats[i].clone(),
          direction: room.seatDirections[i],
        ),
      );
    }
    return result;
  }
}
