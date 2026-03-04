import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'save_migrations.dart';
import 'save_models.dart';
import 'save_repository.dart';

class LocalJsonSaveRepository implements SaveRepository {
  const LocalJsonSaveRepository({
    this.overrideDirectory,
    this.migrationRegistry = const SaveMigrationRegistry(),
  });

  final Directory? overrideDirectory;
  final SaveMigrationRegistry migrationRegistry;

  @override
  Future<List<SaveSlotSummary>> listSlots() async {
    final dir = await _ensureDirectory();
    final summaries = <SaveSlotSummary>[];
    for (final slotId in SaveSlots.all) {
      final file = File('${dir.path}/$slotId.json');
      if (!await file.exists()) {
        continue;
      }
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        continue;
      }
      final payload = migrationRegistry.migrateToLatest(
        decoded.cast<String, dynamic>(),
      );
      final save = GameSaveV1.fromJson(payload);
      summaries.add(
        SaveSlotSummary(
          slotId: slotId,
          savedAtUtc: save.savedAtUtc,
          gameModeKey: save.gameModeKey,
          phase: save.phase,
          round: save.worldState?.round,
          isAutosave: slotId == SaveSlots.autosave,
        ),
      );
    }
    summaries.sort((a, b) => b.savedAtUtc.compareTo(a.savedAtUtc));
    return summaries;
  }

  @override
  Future<void> saveSlot(String slotId, GameSaveV1 save) async {
    _validateSlotId(slotId);
    final dir = await _ensureDirectory();
    final file = File('${dir.path}/$slotId.json');
    final payload = Map<String, dynamic>.from(save.toJson())
      ..['schemaVersion'] = gameSaveSchemaVersion;
    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    await file.writeAsString(encoded);
  }

  @override
  Future<GameSaveV1?> loadSlot(String slotId) async {
    _validateSlotId(slotId);
    final dir = await _ensureDirectory();
    final file = File('${dir.path}/$slotId.json');
    if (!await file.exists()) {
      return null;
    }
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid save file format.');
    }
    final payload = migrationRegistry.migrateToLatest(decoded);
    return GameSaveV1.fromJson(payload);
  }

  @override
  Future<void> deleteSlot(String slotId) async {
    _validateSlotId(slotId);
    final dir = await _ensureDirectory();
    final file = File('${dir.path}/$slotId.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _ensureDirectory() async {
    final root = overrideDirectory ?? await getApplicationDocumentsDirectory();
    final saves = Directory('${root.path}/chesswarss_saves');
    if (!await saves.exists()) {
      await saves.create(recursive: true);
    }
    return saves;
  }

  void _validateSlotId(String slotId) {
    if (!SaveSlots.all.contains(slotId)) {
      throw ArgumentError.value(slotId, 'slotId', 'Unknown save slot id');
    }
  }
}
