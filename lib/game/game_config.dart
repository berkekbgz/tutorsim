import 'package:flutter/material.dart';

/// Static constants for the 3-day MVP. Hardcoded by design.
class GameConfig {
  GameConfig._();

  // World / room
  static const double roomWidth = 640;
  static const double roomHeight = 1664;
  static const double wallThickness = 24;

  // Tutor
  static const double tutorRadius = 16;
  static const double tutorSpeed = 240 * 2;

  /// Which row of the character atlas to use for the tutor sprite.
  /// Easy to change to taste; valid base rows are 0, 3, 6, 9, 12, and 15.
  static const int tutorCharacterRow = 0;

  // Student
  static const double studentRadius = 16;

  // Desk + accessories
  static const int deskCols = 4;
  static const int deskRows = 8;
  static const double deskWidth = 120;
  static const double deskHeight = 40;
  static const double computerWidth = 32;
  static const double computerHeight = 24;
  static const double tabletWidth = 36;
  static const double tabletHeight = 26;

  // Shift / HUD initial values
  static const double shiftSeconds = 300; // 5-minute shift
  static const int startReputation = 100;
  static const int startScore = 0;

  // Camera
  static const double cameraZoom = 1.0;

  // Palette
  static const Color floorColor = Color(0xFF1B1F2A);
  static const Color floorGridColor = Color(0xFF232838);
  static const Color wallColor = Color(0xFF3D4659);
  static const Color deskColor = Color.fromARGB(255, 248, 247, 227);
  static const Color deskEdgeColor = Color(0xFFC8C8C0);
  static const Color computerColor = Color(0xFF1F2A3A);
  static const Color computerScreenColor = Color(0xFF6FB7FF);
  static const Color tabletColor = Color(0xFF2A2F3A);
  static const Color tabletScreenColor = Color(0xFFB0E0FF);
  static const Color studentColor = Color(0xFFE0E4EA);
  static const Color tutorFill = Color(0xFFF0F2F6);

  /// Local login pool — replaced by real API later.
  static const List<String> studentLogins = [
    'bkabagoz',
    'ayilmaz',
    'mertkaya',
    'eozdemir',
    'zcelik',
    'akara',
    'fsahin',
    'ydemir',
  ];
}
