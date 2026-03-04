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
    GameMode.eterna =>
      'Single-player adventure campaign. You command one faction against multiple AI rivals.',
    GameMode.casusBelli =>
      'Arena campaign focus. Fast clashes, flexible map sizes, and local multiplayer-first pacing.',
  };

  String get menuSummary => switch (this) {
    GameMode.eterna =>
      'Adventure campaign: 1 human faction versus multiple AI factions on a larger map.',
    GameMode.casusBelli =>
      'Main focus: compact-to-large arena campaign with immediate conflict.',
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
