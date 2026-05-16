import '../world/cluster_room.dart';
import 'student_npc.dart';

/// Spawns the MVP student roster: one student per login from
/// the given login list, seated at the first N desks.
class StudentFactory {
  StudentFactory(this.room, this.logins);

  final ClusterRoom room;
  final List<String> logins;

  List<StudentNpc> spawnAll() {
    final result = <StudentNpc>[];
    if (logins.isEmpty) return result;

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
