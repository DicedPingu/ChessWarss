import 'save_models.dart';

abstract class SaveMigration {
  int get fromVersion;
  int get toVersion;
  Map<String, dynamic> migrate(Map<String, dynamic> payload);
}

class SaveMigrationRegistry {
  const SaveMigrationRegistry({
    this.latestVersion = gameSaveSchemaVersion,
    this.migrations = const <SaveMigration>[],
  });

  final int latestVersion;
  final List<SaveMigration> migrations;

  Map<String, dynamic> migrateToLatest(Map<String, dynamic> payload) {
    final version = switch (payload['schemaVersion']) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.tryParse(v) ?? gameSaveSchemaVersion,
      _ => gameSaveSchemaVersion,
    };
    if (version == latestVersion) {
      return payload;
    }
    if (version > latestVersion) {
      throw StateError(
        'Unsupported save schema version $version (latest: $latestVersion).',
      );
    }

    var currentVersion = version;
    var currentPayload = Map<String, dynamic>.from(payload);

    while (currentVersion < latestVersion) {
      SaveMigration? migration;
      for (final candidate in migrations) {
        if (candidate.fromVersion == currentVersion) {
          migration = candidate;
          break;
        }
      }
      if (migration == null) {
        throw StateError(
          'No migration path from version $currentVersion to $latestVersion.',
        );
      }
      currentPayload = migration.migrate(currentPayload);
      currentVersion = migration.toVersion;
      currentPayload['schemaVersion'] = currentVersion;
    }

    return currentPayload;
  }
}
