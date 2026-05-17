import '../world/cluster_room.dart';
import 'student_npc.dart';

/// Spawns the MVP student roster: one student per login from
/// the given login list, seated at the first N desks.
class StudentFactory {
  StudentFactory(
    this.room,
    this.logins, {
    required this.releaseSeat,
    required this.requestSeat,
    required this.onExited,
  });

  final ClusterRoom room;
  final List<String> logins;
  final void Function(StudentNpc student) releaseSeat;
  final StudentSeatAssignment? Function(StudentNpc student) requestSeat;
  final void Function(StudentNpc student) onExited;

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
          currentSeatIndex: i,
          findPath: room.findPath,
          randomWalkablePoint: room.randomWalkablePoint,
          releaseSeat: releaseSeat,
          requestSeat: requestSeat,
          onExited: onExited,
        ),
      );
    }
    return result;
  }
}
