import 'package:flutter/material.dart';

/// Static constants for the 3-day MVP. Hardcoded by design.
class GameConfig {
  GameConfig._();

  // World / room
  static const double roomWidth = 640;
  static const double roomHeight = 1664;
  static const double wallThickness = 24;
  static const double rightSceneryWidth = 320;

  // Tutor
  static const double tutorRadius = 16;
  static const double tutorSpeed = 240 * 1.5;

  /// Which row of the character atlas to use for the tutor sprite.
  /// Easy to change to taste; valid base rows are 0, 3, 6, 9, 12, and 15.
  static const int tutorCharacterRow = 0;

  // Student
  static const int targetStudentCount = 24;
  static const double studentRadius = 16;
  static const double studentWalkSpeed = 70;
  static const double studentWanderChancePerSecond = 0.002;
  static const double studentWanderPauseMin = 1.2;
  static const double studentWanderPauseMax = 3.0;
  static const double studentStayMinSeconds = 150;
  static const double studentStayMaxSeconds = 300;
  static const double studentSpawnIntervalMin = 12;
  static const double studentSpawnIntervalMax = 24;

  // Desk + accessories
  static const int deskCols = 4;
  static const int deskRows = 8;
  static const double deskWidth = 120;
  static const double deskHeight = 40;
  static const double computerWidth = 32;
  static const double computerHeight = 24;
  static const double tabletWidth = 36;
  static const double tabletHeight = 26;

  // Events
  static const double firstEventDelay = 4;
  static const double eventIntervalMin = 5;
  static const double eventIntervalMax = 10;
  static const int maxActiveEvents = 3;
  static const double bottleEventVisibleSeconds = 7;
  static const double bottleEventVisibleSecondsMin = 2.5;
  static const double eventExpiryWarningLeadSeconds = 1.5;
  static const double eventCaptureRadius = 72;
  static const int tigHoursPerCapture = 2;
  static const int scorePerCorrectTig = 100;
  static const int scorePerMissedEvent = -30;

  // TIG METRE — the lose condition. Drains continuously and on misses,
  // refills on correct TIGs. Reaching zero ends the run.
  // The effective drain is `tigMetreDrainPerSecond * difficulty`, so
  // pressure escalates with the difficulty ramp: ~100s to empty when
  // idle at game start, ~25s once difficulty plateaus at x4.
  static const int tigMetreMax = 100;
  static const int tigMetreStart = 100;
  static const double tigMetreDrainPerSecond = 1.0;
  static const double tigMetreGainPerCorrectTig = 12;
  static const double tigMetreLossPerMissedEvent = 15;

  // Difficulty ramp. `difficulty` is a unitless multiplier that scales
  // from [difficultyMin] at game start to [difficultyMax] after
  // [difficultyRampSeconds] of play, then plateaus. It feeds spawn rate,
  // concurrent event cap, and how long an event stays catchable.
  static const double difficultyMin = 1.0;
  static const double difficultyMax = 4.0;
  static const double difficultyRampSeconds = 300;
  static const int maxActiveEventsCeiling = 6;

  // HUD initial values
  static const int startScore = 0;

  // Camera
  static const double cameraZoom = 1.0;
  static const double cameraFollowSmoothing = 4.5;

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
