# TutorSim — 3-Day Game Design Document

## 1. High Concept

**TutorSim** is a top-down 2D observation game set inside a fictionalized 42 cluster.

The player controls a single **Tutor** who walks around the cluster, observes students, catches rule violations, takes evidence, and issues TIGs. The game uses 42-style student login IDs to make the cluster feel alive and recognizable.

For the 3-day version, TutorSim is not a full simulation. It is a focused vertical slice built around one core interaction:

> See a rule violation, take a photo, report the correct rule, issue a TIG, and get scored.

---

## 2. Project Scope

### Development Time

**3 days**

### Target Build

A playable web demo made with:

- Flutter
- Flame
- Flutter Web

### Target Experience

A short, replayable arcade/simulation demo where the player tries to catch as many violations as possible before the shift ends or reputation reaches zero.

### Core Promise

By the end of the demo, a player should be able to say:

> “I walked around the cluster, noticed a student breaking a rule, photographed it, selected the correct rule, and issued a TIG.”

Everything outside that loop is optional.

---

## 3. Design Pillars

### 1. Simple Observation

The player should understand what is happening visually. A violation must be readable without complex menus.

### 2. Fast Judgment

The player should quickly decide whether something is a violation or just suspicious behavior.

### 3. Funny 42 Theme

The game should feel like a playful exaggeration of cluster life.

### 4. Small but Polished

For 3 days, polish matters more than number of features.

### 5. Expandable Later

The code structure should allow adding real 42 API integration, more rules, more rooms, and leaderboards later.

---

## 4. Genre

- Top-down observation game
- Light simulation game
- Rule-checking arcade game
- Endless/score-based patrol game

The full future version can become an endless procedural simulator, but the 3-day version is a **vertical slice**.

---

## 5. Player Role

The player is a **Tutor** patrolling the cluster.

The Tutor can:

- Move around
- Inspect nearby students/desks
- Take a photo
- Open a report panel
- Select a rule violation
- Issue a TIG
- Gain or lose score/reputation

The Tutor is not a combat character. The main mechanic is observation and judgment.

---

## 6. Core Gameplay Loop

```txt
Walk around → Notice suspicious behavior → Take photo → Select rule → Issue TIG → Get feedback → Continue patrol
```

### Detailed Loop

1. Students sit or move around the cluster.
2. A rule violation appears.
3. The player notices the violation.
4. The player moves close enough.
5. The player takes a photo.
6. The player opens the report UI.
7. The player selects the suspected rule.
8. The player issues a TIG.
9. The game checks if the report was correct.
10. Score and reputation are updated.

---

## 7. 3-Day MVP Feature List

### Must Have

These features are required for the demo to work.

- One cluster room
- Top-down Tutor movement
- Static desks/computers/tablets
- 8–10 student NPCs
- Login IDs displayed above students
- One main rule violation: **water bottle near tablet/computer**
- One suspicious non-violation: **student carrying bottle but not placing it near desk**
- Camera/photo button
- Report panel
- Rule selection
- TIG button
- Score system
- Reputation system
- Shift timer
- Basic game over / shift summary

### Should Have

Add only if the must-have loop is already working.

- Second violation: **sleeping at computer**
- Simple student walking behavior
- Sound effects
- Small animations
- Chaos increase over time
- Basic minimap or alert indicator

### Could Have

Only if everything else is finished early.

- Third violation: **food on desk**
- Simple leaderboard mock
- 42 OAuth login mock screen
- Student reaction animation
- Particle effects for correct TIG

### Cut From 3-Day Scope

These are not part of the 3-day build.

- Real 42 OAuth
- Real 42 API fetching
- Backend server
- Real campus leaderboard
- Coalition system
- Multiple rooms
- Advanced pathfinding
- Complex AI
- Persistent progression
- Achievements
- Hard rule violations
- Real profile photos
- Multiplayer

---

## 8. Game Session Structure

The 3-day version uses one short shift.

### Shift Length

Recommended:

```txt
3–5 minutes
```

### During the Shift

- Students are present in the room.
- Violations spawn periodically.
- Suspicious harmless events may also appear.
- The player tries to correctly identify violations.

### End Conditions

The session ends when:

- Shift timer reaches zero, or
- Reputation reaches zero.

### End Screen

The shift summary shows:

```txt
Score
Correct TIGs
False TIGs
Missed violations
Accuracy
Final reputation
```

---

## 9. Game Map

### MVP Map

One small cluster room.

Recommended size:

```txt
1280 x 720 or larger scrollable world
```

### Required Objects

- Floor
- Walls or room boundary
- 8–12 desks
- Computers
- Tablets on some desks
- Chairs
- Student spawn points
- Tutor spawn point

### Layout Example

```txt
+------------------------------------------------+
| Entrance                                       |
|                                                |
| [Desk] [Desk] [Desk] [Desk]                   |
| [Desk] [Desk] [Desk] [Desk]                   |
|                                                |
|         Tutor spawn                            |
|                                                |
| [Desk] [Desk] [Desk] [Desk]                   |
+------------------------------------------------+
```

### Implementation Note

For 3 days, the map can be built manually in code using Flame components.

Using Tiled is allowed, but only if the team is already comfortable with it. Manual placement is safer for speed.

---

## 10. Student NPCs

### 3-Day Behavior

Students do not need complex AI.

They can:

- Sit at desks
- Idle
- Occasionally walk to another point
- Carry a water bottle
- Place a bottle near a tablet during a violation
- Sleep at desk if second violation is added

### Student Identity

For the 3-day build, use a local list of real-looking or real 42 login IDs.

Example:

```dart
const studentLogins = [
  'bkabagoz',
  'ayilmaz',
  'mertkaya',
  'eozdemir',
  'zcelik',
  'akara',
  'fsahin',
  'ydemir',
];
```

Real 42 API integration is postponed.

### Student Display

Each student shows:

```txt
Small avatar/sprite
Login ID label above head
Optional state icon
```

### Student States

For MVP:

```txt
IdleAtDesk
Walking
CarryingBottle
ViolationBottlePlaced
Sleeping
```

Only the first four are required.

---

## 11. Rule System

The 3-day version should have a very small rule system.

### Rule 1 — Liquid Near Tablet/Computer

**Description:** A student places a water bottle near a tablet or computer.

**Violation if:**

```txt
Bottle is placed on/near a desk that has a tablet or computer.
```

**Evidence required:**

```txt
Photo includes student + bottle + desk/tablet/computer.
```

**Reward:**

```txt
+100 score
+5 reputation
```

**Wrong report penalty:**

```txt
-50 score
-15 reputation
```

---

### Suspicious Non-Violation — Carrying Bottle

**Description:** A student walks while carrying a bottle.

**This is not a violation.**

It only becomes a violation if the bottle is placed near a tablet/computer.

Purpose:

- Prevent player from blindly reporting every bottle.
- Teach that context matters.

---

### Optional Rule 2 — Sleeping at Computer

**Description:** A student sleeps at a desk.

**Violation if:**

```txt
Student is sleeping while sitting at a computer desk.
```

**Evidence required:**

```txt
Photo includes sleeping student + desk/computer.
```

**Reward:**

```txt
+80 score
+3 reputation
```

---

## 12. Evidence / Photo System

The photo system should be simple.

### Camera Action

When the player presses the camera button:

1. Create a photo object.
2. Detect nearby visible objects in a radius/rectangle.
3. Store what was captured.
4. Show a small flash or photo preview.

### Photo Data

A photo can store:

```txt
Photo
  capturedStudentIds
  capturedObjectTypes
  capturedDeskIds
  timestamp
```

For MVP, the game does not need actual screenshot processing. It only needs to know which game objects were inside the camera area.

### Valid Photo for Bottle Violation

A photo is valid if it contains:

```txt
student
water_bottle
tablet or computer desk
```

---

## 13. Report / TIG System

### Report Flow

1. Player takes photo.
2. Player opens report panel.
3. Player selects a photo.
4. Player selects a rule.
5. Player presses **Issue TIG**.
6. Game validates report.
7. Feedback appears.

### MVP Report Options

```txt
Rule options:
- Liquid near tablet/computer
- Sleeping at computer
- No violation / cancel
```

If sleeping is not implemented, hide that option.

### Result Types

```txt
Correct TIG
Wrong rule
Insufficient evidence
False TIG
Too late
```

### Feedback Messages

Examples:

```txt
Correct TIG! +100
False TIG! Student was just hydrating responsibly.
Insufficient evidence. The bottle was not visible.
Too late. The student cleaned up the desk.
```

---

## 14. Scoring and Reputation

### Score

Score is the main number for replayability.

```txt
Correct TIG: +100
Optional sleeping TIG: +80
False TIG: -50
Insufficient evidence: -20
Missed violation: -30
```

### Reputation

Reputation is the health meter.

```txt
Start reputation: 100
Correct TIG: +5
False TIG: -15
Insufficient evidence: -5
Missed violation: -10
```

If reputation reaches 0, the shift ends.

### Accuracy

At the end of the shift:

```txt
Accuracy = correct TIGs / total submitted TIGs
```

If no reports were submitted, accuracy is 0% or shown as N/A.

---

## 15. Violation Spawning

### MVP Spawn Logic

Every 15–25 seconds:

1. Pick a random student.
2. Pick a random event type.
3. Spawn either:
   - Real bottle violation, or
   - Suspicious bottle carry non-violation.

### Bottle Violation Flow

```txt
Student sits at desk
Bottle object appears near tablet/computer
Violation timer starts
Player has limited time to report
If not reported, violation expires
```

### Expiration

Recommended:

```txt
Violation duration: 20–40 seconds
```

When expired:

- Bottle disappears or student removes it.
- Player loses small reputation/score if it was missed.

---

## 16. Controls

### Desktop Web Controls

```txt
WASD / Arrow Keys  → Move Tutor
Mouse              → Aim/select
Space / E          → Inspect or interact
C                  → Take photo
R                  → Open report panel
Esc                → Pause / close panel
```

### UI Buttons

Because this is Flutter Web, also include clickable buttons:

```txt
Camera
Report
Rulebook
Pause
```

---

## 17. UI Screens

### Main Menu

Required:

```txt
TutorSim logo
Start Shift button
Short disclaimer
```

Optional:

```txt
Mock Login with 42 button
```

### HUD

```txt
Score | Reputation | Time Left | Correct TIGs | False TIGs
```

### Report Panel

Shows:

```txt
Last photo / selected photo
Captured student login IDs
Rule dropdown/buttons
Issue TIG button
Cancel button
```

### Shift Summary

Shows:

```txt
Final Score
Correct TIGs
False TIGs
Missed Violations
Accuracy
Restart button
```

---

## 18. Visual Style

### Recommended Style for 3 Days

Use simple shapes or minimal sprites.

Do not spend too much time on art.

### Required Visual Clarity

The player must easily recognize:

- Tutor
- Students
- Desks
- Computers/tablets
- Water bottle
- Sleeping student, if implemented
- Camera/photo feedback
- Correct/wrong report feedback

### Suggested Visual Approach

```txt
Tutor: distinct colored character
Students: simple circles/characters with login labels
Desks: rectangles
Computers/tablets: small dark rectangles
Bottle: small blue object/icon
Violation: no obvious red marker unless the player inspects closely
```

The game should not highlight violations too aggressively. The player should observe them.

---

## 19. Audio

Audio is optional but valuable for polish.

### High-Priority Sounds

- Camera shutter
- Correct TIG
- Wrong TIG
- Shift end

### Low-Priority Sounds

- Footsteps
- Keyboard typing ambience
- Cluster background noise

---

## 20. 42 API Plan

### 3-Day Build

Do not implement real 42 API unless the rest of the game is already done.

Use a local list of login IDs.

### Future Build

After the demo works:

```txt
Flutter Web → TutorSim Backend → 42 API
```

The Flutter Web client must not contain the 42 API secret.

### Future API Uses

- 42 OAuth login
- Player profile
- Campus
- Coalition
- Leaderboards
- Real login ID pool, if allowed

---

## 21. Privacy and Fiction Disclaimer

Because the game uses real or real-looking login IDs, the demo should include a disclaimer.

### Disclaimer Text

```txt
TutorSim is a fictional simulation. In-game student behavior is randomly generated and does not represent real actions, discipline history, or rule violations by actual 42 students.
```

### 3-Day Data Rule

For the demo:

- Do not use real profile photos.
- Do not store generated violations attached to real people.
- Do not publish “student X broke rule Y” outside the active match.
- Use login IDs only for flavor.

---

## 22. Technical Structure

### Flutter / Flame Structure

```txt
lib/
  main.dart

  game/
    tutor_sim_game.dart
    game_config.dart

    world/
      cluster_world.dart
      cluster_room.dart

    tutor/
      tutor_player.dart
      tutor_controller.dart
      camera_tool.dart

    students/
      student_npc.dart
      student_state.dart
      student_factory.dart

    objects/
      desk.dart
      computer.dart
      tablet.dart
      water_bottle.dart

    rules/
      rule.dart
      rule_violation.dart
      violation_director.dart
      evidence_checker.dart

    reports/
      photo_evidence.dart
      report_system.dart
      tig_system.dart

    progression/
      score_system.dart
      shift_timer.dart
      reputation_system.dart

    ui/
      hud_overlay.dart
      report_overlay.dart
      shift_summary_overlay.dart
      main_menu_overlay.dart
```

### Recommended Implementation Style

Keep systems simple.

Avoid over-engineering.

Prefer:

```txt
simple components
hardcoded map positions
small data classes
basic timers
clear event flow
```

Avoid during 3-day build:

```txt
complex ECS
advanced pathfinding
backend dependency
real OAuth
large asset pipeline
```

---

## 23. Main Components

### TutorPlayer

Responsible for:

- Movement
- Collision with room bounds/desks
- Camera position
- Interaction range

### StudentNpc

Responsible for:

- Displaying login ID
- Current state
- Simple movement/idle animation
- Holding or placing objects

### ViolationDirector

Responsible for:

- Spawning bottle violations
- Spawning suspicious non-violations
- Timing violations
- Marking missed violations

### CameraTool

Responsible for:

- Capturing nearby objects
- Creating photo evidence
- Playing camera feedback

### EvidenceChecker

Responsible for:

- Checking selected photo
- Checking selected rule
- Returning report result

### TigSystem

Responsible for:

- Applying score
- Applying reputation change
- Showing feedback
- Resolving violation

---

## 24. 3-Day Development Plan

### Day 1 — Playable Cluster

Goal:

> The player can move around a cluster that contains desks and students.

Tasks:

- Create Flutter/Flame project
- Add main menu/start button
- Add cluster room
- Add desks/computers/tablets
- Add Tutor movement
- Add camera following
- Add student NPCs with login labels
- Add basic HUD

End-of-day result:

```txt
A Tutor can walk around a 42-style cluster with students visible.
```

---

### Day 2 — Core TIG Loop

Goal:

> The player can catch a water bottle violation and issue a TIG.

Tasks:

- Add water bottle object
- Add ViolationDirector
- Spawn bottle near tablet/computer
- Add camera/photo mechanic
- Add report panel
- Add rule selection
- Add TIG validation
- Add score/reputation changes
- Add correct/wrong feedback

End-of-day result:

```txt
The main game loop works: observe → photo → report → TIG → score.
```

---

### Day 3 — Polish and Demo Readiness

Goal:

> The game feels complete enough to present.

Tasks:

- Add suspicious non-violation event
- Add shift timer
- Add shift summary screen
- Add restart flow
- Add simple sounds or visual effects
- Add missing feedback messages
- Fix bugs
- Improve readability
- Optional: add sleeping violation

End-of-day result:

```txt
A playable 3–5 minute TutorSim demo with scoring and replayability.
```

---

## 25. Demo Success Criteria

The demo is successful if:

- The player understands they are a Tutor.
- The player understands they are in a 42-style cluster.
- The player can identify a water bottle violation.
- The player can take a photo.
- The player can issue a TIG.
- The game gives clear correct/wrong feedback.
- The player wants to retry for a better score.

The demo fails if:

- The player cannot tell what is a violation.
- The report flow is confusing.
- The game feels empty or static.
- The player can spam TIGs without thinking.
- Too much time is spent on API/backend before gameplay works.

---

## 26. Future Expansion

After the 3-day demo, TutorSim can expand into the full vision.

### Future Features

- Real 42 OAuth
- Backend
- Real campus login pool
- Campus leaderboard
- Coalition leaderboard
- Multiple cluster rooms
- More rule violations
- Better NPC behavior
- More evidence types
- Warnings vs TIG distinction
- Achievements
- Tutor ranks
- Weekly challenges
- Procedural endless mode

---

## 27. Final 3-Day Product Statement

**TutorSim** is a small but polished 42 cluster patrol game where the player controls a Tutor, watches students with login IDs, catches fictional rule violations, takes photo evidence, and issues TIGs for score.

The 3-day version should focus only on the essential fun:

> Walk around, notice a bottle near a tablet, photograph it, report it, issue TIG, get points.

If that loop feels good, the game can grow after the demo.

