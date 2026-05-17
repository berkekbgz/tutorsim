enum StudentPersonality { regular, chaotic, sneaky, sleepy, loud }

const Map<StudentPersonality, int> studentPersonalityBodyColors = {
  StudentPersonality.regular: 0xFF7A8EA8,
  StudentPersonality.chaotic: 0xFFC96F58,
  StudentPersonality.sneaky: 0xFF7167A8,
  StudentPersonality.sleepy: 0xFF6FA88F,
  StudentPersonality.loud: 0xFFC49A4A,
};

StudentPersonality personalityForLogin(String login) {
  var hash = 0;
  for (final unit in login.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }

  final values = StudentPersonality.values;
  return values[hash % values.length];
}

extension StudentPersonalityTuning on StudentPersonality {
  double get eventWeightMultiplier {
    return switch (this) {
      StudentPersonality.regular => 1.0,
      StudentPersonality.chaotic => 1.9,
      StudentPersonality.sneaky => 1.35,
      StudentPersonality.sleepy => 0.8,
      StudentPersonality.loud => 1.55,
    };
  }

  double get wanderChanceMultiplier {
    return switch (this) {
      StudentPersonality.regular => 1.0,
      StudentPersonality.chaotic => 1.7,
      StudentPersonality.sneaky => 0.75,
      StudentPersonality.sleepy => 0.45,
      StudentPersonality.loud => 1.35,
    };
  }

  double get eventDurationMultiplier {
    return switch (this) {
      StudentPersonality.regular => 1.0,
      StudentPersonality.chaotic => 0.9,
      StudentPersonality.sneaky => 0.6,
      StudentPersonality.sleepy => 1.25,
      StudentPersonality.loud => 1.0,
    };
  }

  double get coffeeEventWeight {
    return switch (this) {
      StudentPersonality.regular => 1.0,
      StudentPersonality.chaotic => 1.25,
      StudentPersonality.sneaky => 1.65,
      StudentPersonality.sleepy => 0.75,
      StudentPersonality.loud => 1.35,
    };
  }

  double get bottleEventWeight {
    return switch (this) {
      StudentPersonality.regular => 1.0,
      StudentPersonality.chaotic => 1.75,
      StudentPersonality.sneaky => 0.8,
      StudentPersonality.sleepy => 0.75,
      StudentPersonality.loud => 1.1,
    };
  }

  double get sleepEventWeight {
    return switch (this) {
      StudentPersonality.regular => 0.6,
      StudentPersonality.chaotic => 0.35,
      StudentPersonality.sneaky => 0.7,
      StudentPersonality.sleepy => 2.6,
      StudentPersonality.loud => 0.3,
    };
  }

  double get quitAfterTigChance {
    return switch (this) {
      StudentPersonality.regular => 0.05,
      StudentPersonality.chaotic => 0.12,
      StudentPersonality.sneaky => 0.2,
      StudentPersonality.sleepy => 0.14,
      StudentPersonality.loud => 0.1,
    };
  }

  List<String> get eventLines {
    return switch (this) {
      StudentPersonality.regular => const ['...', '!?', 'hm.'],
      StudentPersonality.chaotic => const ['@#*%!!', '!!!', '*&%!?'],
      StudentPersonality.sneaky => const ['...', '??', '...!'],
      StudentPersonality.sleepy => const ['zzz', 'zz..?', '...'],
      StudentPersonality.loud => const ['!!!', '@@!!', '#?!'],
    };
  }

  List<String> get caughtLines {
    return switch (this) {
      StudentPersonality.regular => const ['!?', '...', '!!'],
      StudentPersonality.chaotic => const ['@#*%!!!!', '%#@!!', '!!!?!'],
      StudentPersonality.sneaky => const ['...', '!?!!', '#@?'],
      StudentPersonality.sleepy => const ['zz?!', '...', '?!'],
      StudentPersonality.loud => const ['@#@#!!', '!!!!', '#!?!!'],
    };
  }

  List<String> get arrivalLines {
    return switch (this) {
      StudentPersonality.regular => const ['...', '..!'],
      StudentPersonality.chaotic => const ['!!!', '@@!'],
      StudentPersonality.sneaky => const ['...', '. . .'],
      StudentPersonality.sleepy => const ['zzz', '..zz'],
      StudentPersonality.loud => const ['!!', '!!!'],
    };
  }

  List<String> get leavingLines {
    return switch (this) {
      StudentPersonality.regular => const ['...', '..'],
      StudentPersonality.chaotic => const ['@#*!', '!!!'],
      StudentPersonality.sneaky => const ['...', '..?'],
      StudentPersonality.sleepy => const ['zzz', '...'],
      StudentPersonality.loud => const ['!!!', '#!!'],
    };
  }
}
