import 'dart:io';

import 'package:chesswarss/src/application/save/local_json_save_repository.dart';
import 'package:chesswarss/src/application/save/save_models.dart';
import 'package:chesswarss/src/application/settings/settings_models.dart';
import 'package:chesswarss/src/domain/ai.dart';
import 'package:chesswarss/src/domain/world.dart';
import 'package:chesswarss/src/domain/world_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalJsonSaveRepository', () {
    late Directory tempDir;
    late LocalJsonSaveRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'chesswarss_save_repo_test_',
      );
      repository = LocalJsonSaveRepository(overrideDirectory: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('roundtrips manual save slot', () async {
      const generator = WorldGenerator();
      final world = generator.create(
        playerCount: 2,
        playerTypes: const [PlayerType.human, PlayerType.ai],
        preset: MapPreset.greatField,
        seed: 77,
      );

      final snapshot = GameSaveV1(
        schemaVersion: gameSaveSchemaVersion,
        savedAtUtc: DateTime.utc(2026, 2, 24, 12, 0),
        gameModeKey: 'casusBelli',
        phase: SavedGamePhase.world,
        seed: world.seed,
        playerCount: 2,
        mapSize: world.size,
        armiesPerPlayer: 3,
        mapPreset: world.preset,
        aiDifficulty: AiDifficulty.normal,
        playerTypes: const [
          PlayerType.human,
          PlayerType.ai,
          PlayerType.ai,
          PlayerType.ai,
        ],
        worldState: world,
        battleSession: null,
        statusLine: 'Round ${world.round}',
        selectedStackId: null,
        forcedMarchMode: false,
        selectedBattlePieceId: null,
        campaignOnboardingSeen: false,
        stackSupplyById: const <String, int>{'P1-A1': 4},
        stackStarvationById: const <String, int>{'P1-A1': 0},
        stackWaterById: const <String, int>{'P1-A1': 4},
        stackThirstById: const <String, int>{'P1-A1': 0},
        capturePolicyByPlayer: const <int, String>{0: 'spare', 1: 'destroy'},
        foodTileOwnerByPosition: const <String, int>{'4,0': 0},
        pillagedTileUntilRound: const <String, int>{'2,2': 3},
        settings: const GameSettingsSnapshot(
          animationSpeed: 1.0,
          aiDelayMs: 750,
          reducedEffects: false,
        ),
      );

      await repository.saveSlot(SaveSlots.slot1, snapshot);
      final loaded = await repository.loadSlot(SaveSlots.slot1);

      expect(loaded, isNotNull);
      expect(loaded!.schemaVersion, gameSaveSchemaVersion);
      expect(loaded.gameModeKey, 'casusBelli');
      expect(loaded.phase, SavedGamePhase.world);
      expect(loaded.worldState, isNotNull);
      expect(loaded.worldState!.size, world.size);
      expect(loaded.worldState!.seed, world.seed);
      expect(loaded.worldState!.stacks.length, world.stacks.length);
      expect(loaded.stackWaterById['P1-A1'], 4);
      expect(loaded.foodTileOwnerByPosition['4,0'], 0);
      expect(loaded.settings.aiDelayMs, 750);
    });

    test('lists summaries for manual and autosave slots', () async {
      const generator = WorldGenerator();
      final world = generator.create(
        playerCount: 2,
        playerTypes: const [PlayerType.human, PlayerType.ai],
        preset: MapPreset.tightRavine,
        seed: 99,
      );

      final base = GameSaveV1(
        schemaVersion: gameSaveSchemaVersion,
        savedAtUtc: DateTime.utc(2026, 2, 24, 10, 30),
        gameModeKey: 'eterna',
        phase: SavedGamePhase.world,
        seed: world.seed,
        playerCount: 2,
        mapSize: world.size,
        armiesPerPlayer: 4,
        mapPreset: world.preset,
        aiDifficulty: AiDifficulty.easy,
        playerTypes: const [PlayerType.human, PlayerType.ai],
        worldState: world,
        battleSession: null,
        statusLine: 'Loaded',
        selectedStackId: null,
        forcedMarchMode: false,
        selectedBattlePieceId: null,
        campaignOnboardingSeen: false,
        stackSupplyById: const <String, int>{},
        stackStarvationById: const <String, int>{},
        stackWaterById: const <String, int>{},
        stackThirstById: const <String, int>{},
        capturePolicyByPlayer: const <int, String>{},
        foodTileOwnerByPosition: const <String, int>{},
        pillagedTileUntilRound: const <String, int>{},
        settings: GameSettingsSnapshot.defaults,
      );
      await repository.saveSlot(SaveSlots.slot2, base);
      await repository.saveSlot(
        SaveSlots.autosave,
        GameSaveV1(
          schemaVersion: gameSaveSchemaVersion,
          savedAtUtc: DateTime.utc(2026, 2, 24, 11, 0),
          gameModeKey: 'casusBelli',
          phase: SavedGamePhase.battle,
          seed: world.seed,
          playerCount: 2,
          mapSize: world.size,
          armiesPerPlayer: 3,
          mapPreset: world.preset,
          aiDifficulty: AiDifficulty.hard,
          playerTypes: const [PlayerType.human, PlayerType.ai],
          worldState: world,
          battleSession: null,
          statusLine: 'Autosaved',
          selectedStackId: null,
          forcedMarchMode: false,
          selectedBattlePieceId: null,
          campaignOnboardingSeen: true,
          stackSupplyById: const <String, int>{},
          stackStarvationById: const <String, int>{},
          stackWaterById: const <String, int>{},
          stackThirstById: const <String, int>{},
          capturePolicyByPlayer: const <int, String>{},
          foodTileOwnerByPosition: const <String, int>{},
          pillagedTileUntilRound: const <String, int>{},
          settings: GameSettingsSnapshot.defaults,
        ),
      );

      final summaries = await repository.listSlots();
      expect(
        summaries.map((entry) => entry.slotId),
        containsAll(<String>[SaveSlots.slot2, SaveSlots.autosave]),
      );
      expect(
        summaries.any(
          (entry) => entry.slotId == SaveSlots.autosave && entry.isAutosave,
        ),
        isTrue,
      );
    });

    test('deletes slot content', () async {
      const generator = WorldGenerator();
      final world = generator.create(
        playerCount: 2,
        playerTypes: const [PlayerType.human, PlayerType.ai],
        preset: MapPreset.greatField,
        seed: 7,
      );
      final snapshot = GameSaveV1(
        schemaVersion: gameSaveSchemaVersion,
        savedAtUtc: DateTime.utc(2026, 2, 24, 8, 0),
        gameModeKey: 'casusBelli',
        phase: SavedGamePhase.world,
        seed: world.seed,
        playerCount: 2,
        mapSize: world.size,
        armiesPerPlayer: 3,
        mapPreset: world.preset,
        aiDifficulty: AiDifficulty.normal,
        playerTypes: const [PlayerType.human, PlayerType.ai],
        worldState: world,
        battleSession: null,
        statusLine: 'test',
        selectedStackId: null,
        forcedMarchMode: false,
        selectedBattlePieceId: null,
        campaignOnboardingSeen: false,
        stackSupplyById: const <String, int>{},
        stackStarvationById: const <String, int>{},
        stackWaterById: const <String, int>{},
        stackThirstById: const <String, int>{},
        capturePolicyByPlayer: const <int, String>{},
        foodTileOwnerByPosition: const <String, int>{},
        pillagedTileUntilRound: const <String, int>{},
        settings: GameSettingsSnapshot.defaults,
      );

      await repository.saveSlot(SaveSlots.slot3, snapshot);
      expect(await repository.loadSlot(SaveSlots.slot3), isNotNull);

      await repository.deleteSlot(SaveSlots.slot3);
      expect(await repository.loadSlot(SaveSlots.slot3), isNull);
    });
  });
}
