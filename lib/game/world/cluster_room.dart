import 'dart:ui';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import '../game_config.dart';
import '../objects/computer.dart';
import '../sprites.dart';

/// The single cluster room for the MVP. Each row is a continuous bench
/// (4 desks merged into one rectangle). Within a row, adjacent desks face
/// opposite directions so students sit on alternating sides of the bench.
class ClusterRoom extends PositionComponent {
  ClusterRoom()
    : super(size: Vector2(GameConfig.roomWidth, GameConfig.roomHeight));

  /// World-space rectangles for the merged benches. Used for tutor blocking.
  final List<Rect> benchRects = [];

  /// Where students sit (one per desk slot, in row-major order).
  final List<Vector2> seats = [];

  /// Desk positions where event props can appear.
  final List<Vector2> eventSpots = [];

  /// Seat index associated with each event spot.
  final List<int> eventSeatIndices = [];

  /// Direction each seated student should face based on table side.
  final List<CharacterDirection> seatDirections = [];

  /// Off-room staff corridor spawn. NPCs can use it, but the tutor remains
  /// blocked by the room bounds.
  Vector2 get gateSpawnPoint => Vector2(GameConfig.roomWidth / 2, -48);

  /// Accessories on the benches (computer or tablet). Will be used by
  /// the photo / violation systems later.
  final List<DeskAccessory> accessories = [];

  static const int _cols = GameConfig.deskCols;
  static const int _rows = GameConfig.deskRows;
  static const double _benchCenterX =
      GameConfig.roomWidth / 2 + GameConfig.wallThickness;
  static const double _benchStartY = 300;
  static const double _rowSpacingY = 120;
  static const double _pathCellSize = 32;

  late final Image _floorTile;

  @override
  Future<void> onLoad() async {
    _floorTile = await Flame.images.load('floor.png');
    var scrollingComputers = 0;

    for (int r = 0; r < _rows; r++) {
      final benchY = _benchStartY + r * _rowSpacingY;
      final benchW = _cols * GameConfig.deskWidth;
      final benchX = _benchCenterX - benchW / 2;
      benchRects.add(
        Rect.fromLTWH(benchX, benchY, benchW, GameConfig.deskHeight),
      );

      for (int c = 0; c < _cols; c++) {
        final screenFacesUp = c.isOdd;
        final deskX = benchX + c * GameConfig.deskWidth;

        final accW = GameConfig.computerWidth;
        final accH = GameConfig.computerHeight;
        final accX = deskX + (GameConfig.deskWidth - accW) / 2;
        final accY = screenFacesUp
            ? benchY + 6
            : benchY + GameConfig.deskHeight - accH - 6;
        final scrolling = !screenFacesUp && scrollingComputers < 3;
        if (scrolling) scrollingComputers++;
        await add(
          Computer(
            position: Vector2(accX, accY),
            facingBack: screenFacesUp,
            scrolling: scrolling,
          ),
        );
        accessories.add(
          DeskAccessory(
            kind: DeskAccessoryKind.computer,
            rect: Rect.fromLTWH(accX, accY, accW, accH),
          ),
        );

        final seatX = deskX + GameConfig.deskWidth / 2;
        final seatY = screenFacesUp
            ? benchY - GameConfig.studentRadius - 6
            : benchY + GameConfig.deskHeight + GameConfig.studentRadius + 6;
        seats.add(Vector2(seatX, seatY));
        final seatDirection = screenFacesUp
            ? CharacterDirection.down
            : CharacterDirection.up;
        seatDirections.add(seatDirection);
        eventSpots.add(
          _eventSpotForScreen(
            Rect.fromLTWH(accX, accY, accW, accH),
            seatDirection,
          ),
        );
        eventSeatIndices.add(seats.length - 1);
      }
    }
  }

  Vector2 _eventSpotForScreen(Rect screen, CharacterDirection npcDirection) {
    const bottleSize = 24.0;
    const margin = 4.0;
    final x = npcDirection == CharacterDirection.up
        ? screen.left - bottleSize / 2 - margin
        : screen.right + bottleSize / 2 + margin;

    return Vector2(x, screen.center.dy);
  }

  /// True if a circle at [center] with [radius] overlaps any bench.
  bool isBlocked(Vector2 center, double radius) {
    for (final r in benchRects) {
      final cx = center.x.clamp(r.left, r.right);
      final cy = center.y.clamp(r.top, r.bottom);
      final dx = center.x - cx;
      final dy = center.y - cy;
      if (dx * dx + dy * dy < radius * radius) return true;
    }
    return false;
  }

  bool isWalkable(Vector2 center, double radius) {
    final minX = GameConfig.wallThickness + radius;
    final maxX = GameConfig.roomWidth - GameConfig.wallThickness - radius;
    final minY = GameConfig.wallThickness + radius;
    final maxY = GameConfig.roomHeight - GameConfig.wallThickness - radius;
    if (center.x < minX ||
        center.x > maxX ||
        center.y < minY ||
        center.y > maxY) {
      return false;
    }
    return !isBlocked(center, radius);
  }

  Vector2 randomWalkablePoint(math.Random random, double radius) {
    for (int attempt = 0; attempt < 100; attempt++) {
      final point = Vector2(
        GameConfig.wallThickness +
            radius +
            random.nextDouble() *
                (GameConfig.roomWidth -
                    2 * (GameConfig.wallThickness + radius)),
        GameConfig.wallThickness +
            radius +
            random.nextDouble() *
                (GameConfig.roomHeight -
                    2 * (GameConfig.wallThickness + radius)),
      );
      if (isWalkable(point, radius)) return point;
    }

    return Vector2(GameConfig.roomWidth / 2, GameConfig.wallThickness + radius);
  }

  List<Vector2> findPath(Vector2 start, Vector2 goal, double radius) {
    final cols = (GameConfig.roomWidth / _pathCellSize).ceil();
    final rows = (GameConfig.roomHeight / _pathCellSize).ceil();
    final startCell = _nearestWalkableCell(
      _cellFor(start, cols, rows),
      radius,
      cols,
      rows,
    );
    final goalCell = _nearestWalkableCell(
      _cellFor(goal, cols, rows),
      radius,
      cols,
      rows,
    );
    if (startCell == null || goalCell == null) return const [];

    final open = <_PathNode>[
      _PathNode(startCell, 0, _heuristic(startCell, goalCell)),
    ];
    final cameFrom = <int, _GridCell>{};
    final bestCost = <int, double>{startCell.key(cols): 0};
    final closed = <int>{};

    while (open.isNotEmpty) {
      open.sort((a, b) => a.estimatedTotal.compareTo(b.estimatedTotal));
      final current = open.removeAt(0);
      final currentKey = current.cell.key(cols);
      if (!closed.add(currentKey)) continue;

      if (current.cell == goalCell) {
        return _reconstructPath(cameFrom, current.cell, startCell, goal, cols);
      }

      for (final neighbor in current.cell.neighbors(cols, rows)) {
        final neighborKey = neighbor.key(cols);
        if (closed.contains(neighborKey)) continue;
        if (!isWalkable(_cellCenter(neighbor), radius)) continue;

        final newCost = current.cost + 1;
        if (newCost >= (bestCost[neighborKey] ?? double.infinity)) continue;

        bestCost[neighborKey] = newCost;
        cameFrom[neighborKey] = current.cell;
        open.add(
          _PathNode(
            neighbor,
            newCost,
            newCost + _heuristic(neighbor, goalCell),
          ),
        );
      }
    }

    return const [];
  }

  _GridCell _cellFor(Vector2 point, int cols, int rows) {
    return _GridCell(
      (point.x / _pathCellSize).floor().clamp(0, cols - 1),
      (point.y / _pathCellSize).floor().clamp(0, rows - 1),
    );
  }

  _GridCell? _nearestWalkableCell(
    _GridCell origin,
    double radius,
    int cols,
    int rows,
  ) {
    if (isWalkable(_cellCenter(origin), radius)) return origin;

    for (int range = 1; range <= 4; range++) {
      for (int y = origin.y - range; y <= origin.y + range; y++) {
        for (int x = origin.x - range; x <= origin.x + range; x++) {
          if (x < 0 || x >= cols || y < 0 || y >= rows) continue;
          final cell = _GridCell(x, y);
          if (isWalkable(_cellCenter(cell), radius)) return cell;
        }
      }
    }

    return null;
  }

  Vector2 _cellCenter(_GridCell cell) {
    return Vector2(
      cell.x * _pathCellSize + _pathCellSize / 2,
      cell.y * _pathCellSize + _pathCellSize / 2,
    );
  }

  double _heuristic(_GridCell a, _GridCell b) {
    return (a.x - b.x).abs() + (a.y - b.y).abs().toDouble();
  }

  List<Vector2> _reconstructPath(
    Map<int, _GridCell> cameFrom,
    _GridCell current,
    _GridCell start,
    Vector2 exactGoal,
    int cols,
  ) {
    final cells = <_GridCell>[current];
    while (current != start) {
      current = cameFrom[current.key(cols)]!;
      cells.add(current);
    }

    return cells.reversed.skip(1).map(_cellCenter).followedBy([
      exactGoal,
    ]).toList();
  }

  // Cached paints — render() runs every frame.
  static final _floorPaint = Paint()..filterQuality = FilterQuality.none;
  static final _wallPaint = Paint()..color = GameConfig.wallColor;
  static final _corridorPaint = Paint()..color = const Color(0xFF151923);
  static final _corridorEdgePaint = Paint()
    ..color = const Color(0xFF596275)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _doorPaint = Paint()..color = const Color(0xFF0E1119);
  static final _doorEdgePaint = Paint()
    ..color = const Color(0xFF8C95A8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _benchFill = Paint()..color = GameConfig.deskColor;
  static final _benchEdge = Paint()
    ..color = GameConfig.deskEdgeColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void render(Canvas canvas) {
    final w = GameConfig.roomWidth;
    final h = GameConfig.roomHeight;
    final t = GameConfig.wallThickness;

    _renderFloor(canvas, w, h);

    final corridor = Rect.fromCenter(
      center: Offset(w / 2, -36),
      width: 128,
      height: 96,
    );
    canvas.drawRect(corridor, _corridorPaint);
    canvas.drawRect(corridor, _corridorEdgePaint);

    // Walls (four edge bands).
    canvas.drawRect(Rect.fromLTWH(0, 0, w, t), _wallPaint);
    canvas.drawRect(Rect.fromLTWH(0, h - t, w, t), _wallPaint);
    canvas.drawRect(Rect.fromLTWH(0, 0, t, h), _wallPaint);
    canvas.drawRect(Rect.fromLTWH(w - t, 0, t, h), _wallPaint);

    final staffDoor = Rect.fromCenter(
      center: Offset(w / 2, t / 2),
      width: 72,
      height: t,
    );
    canvas.drawRect(staffDoor, _doorPaint);
    canvas.drawRect(staffDoor, _doorEdgePaint);

    // Merged benches: one rounded rect per row.
    for (final b in benchRects) {
      canvas.drawRect(b, _benchFill);
      canvas.drawRect(b, _benchEdge);
    }
  }

  void _renderFloor(Canvas canvas, double width, double height) {
    final src = Rect.fromLTWH(
      0,
      0,
      _floorTile.width.toDouble(),
      _floorTile.height.toDouble(),
    );
    final tileWidth = _floorTile.width.toDouble();
    final tileHeight = _floorTile.height.toDouble();
    final cols = (width / tileWidth).ceil();
    final rows = (height / tileHeight).ceil();

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final left = x * tileWidth;
        final top = y * tileHeight;
        final dest = Rect.fromLTWH(left, top, tileWidth, tileHeight);

        if ((x + y).isEven) {
          canvas.drawImageRect(_floorTile, src, dest, _floorPaint);
        } else {
          canvas.save();
          canvas.translate(left + tileWidth / 2, top + tileHeight / 2);
          canvas.rotate(math.pi / 2);
          canvas.translate(-tileWidth / 2, -tileHeight / 2);
          canvas.drawImageRect(
            _floorTile,
            src,
            Rect.fromLTWH(0, 0, tileWidth, tileHeight),
            _floorPaint,
          );
          canvas.restore();
        }
      }
    }
  }
}

enum DeskAccessoryKind { computer, tablet }

class DeskAccessory {
  final DeskAccessoryKind kind;
  final Rect rect;
  DeskAccessory({required this.kind, required this.rect});
}

class _GridCell {
  const _GridCell(this.x, this.y);

  final int x;
  final int y;

  int key(int cols) => y * cols + x;

  Iterable<_GridCell> neighbors(int cols, int rows) sync* {
    if (x > 0) yield _GridCell(x - 1, y);
    if (x < cols - 1) yield _GridCell(x + 1, y);
    if (y > 0) yield _GridCell(x, y - 1);
    if (y < rows - 1) yield _GridCell(x, y + 1);
  }

  @override
  bool operator ==(Object other) {
    return other is _GridCell && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);
}

class _PathNode {
  const _PathNode(this.cell, this.cost, this.estimatedTotal);

  final _GridCell cell;
  final double cost;
  final double estimatedTotal;
}
