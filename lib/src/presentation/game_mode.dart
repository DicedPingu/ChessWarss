enum GameMode { eterna, casusBelli }

extension GameModeUi on GameMode {
  String get storageKey => switch (this) {
    GameMode.eterna => 'eterna',
    GameMode.casusBelli => 'casusBelli',
  };

  String get label => switch (this) {
    GameMode.eterna => 'Eterna Mode',
    GameMode.casusBelli => 'Casus Belli',
  };

  String get setupSubtitle => switch (this) {
    GameMode.eterna => 'Single-player war-chess campaign against AI rivals.',
    GameMode.casusBelli =>
      'Fast arena campaign with local multiplayer-first pacing.',
  };

  String get menuSummary => switch (this) {
    GameMode.eterna =>
      'One faction, several rivals, and battles resolved on readable chess boards.',
    GameMode.casusBelli =>
      'Compact-to-large arena maps tuned for immediate conflict.',
  };

  int get minMapSize => switch (this) {
    GameMode.eterna => 8,
    GameMode.casusBelli => 3,
  };

  int get maxMapSize => 10;

  int get minPlayerCount => 2;

  int get maxPlayerCount => switch (this) {
    GameMode.eterna => 4,
    GameMode.casusBelli => 4,
  };

  int get defaultPlayerCount => switch (this) {
    GameMode.eterna => 4,
    GameMode.casusBelli => 2,
  };

  int defaultMapSizeForPlayers(int players) {
    return switch (this) {
      GameMode.eterna => 9,
      GameMode.casusBelli => players <= 2 ? 5 : 7,
    };
  }

  int maxArmiesForMapSize(int mapSize) {
    if (mapSize <= 3) {
      return 3;
    }
    return 4;
  }

  int get defaultArmies => switch (this) {
    GameMode.eterna => 4,
    GameMode.casusBelli => 3,
  };

  bool get playerControlEditable => this == GameMode.casusBelli;

  bool get usesTempoRules => this == GameMode.casusBelli;
}

GameMode gameModeFromStorageKey(String? value) {
  switch (value) {
    case 'eterna':
      return GameMode.eterna;
    case 'casusBelli':
      return GameMode.casusBelli;
    default:
      return GameMode.casusBelli;
  }
}
