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

  /// Direction each seated student should face based on table side.
  final List<CharacterDirection> seatDirections = [];

  /// Accessories on the benches (computer or tablet). Will be used by
  /// the photo / violation systems later.
  final List<DeskAccessory> accessories = [];

  static const int _cols = 4;
  static const int _rows = 8;
  static const double _benchCenterX =
      GameConfig.roomWidth / 2 + GameConfig.wallThickness;
  static const double _benchStartY = 300;
  static const double _rowSpacingY = 120;

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
        seatDirections.add(
          screenFacesUp ? CharacterDirection.down : CharacterDirection.up,
        );
      }
    }
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

  // Cached paints — render() runs every frame.
  static final _floorPaint = Paint()..filterQuality = FilterQuality.none;
  static final _wallPaint = Paint()..color = GameConfig.wallColor;
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

    // Walls (four edge bands).
    canvas.drawRect(Rect.fromLTWH(0, 0, w, t), _wallPaint);
    canvas.drawRect(Rect.fromLTWH(0, h - t, w, t), _wallPaint);
    canvas.drawRect(Rect.fromLTWH(0, 0, t, h), _wallPaint);
    canvas.drawRect(Rect.fromLTWH(w - t, 0, t, h), _wallPaint);

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
