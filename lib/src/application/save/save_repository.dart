import 'save_models.dart';

class SaveSlotSummary {
  const SaveSlotSummary({
    required this.slotId,
    required this.savedAtUtc,
    required this.gameModeKey,
    required this.phase,
    required this.round,
    required this.isAutosave,
  });

  final String slotId;
  final DateTime savedAtUtc;
  final String gameModeKey;
  final SavedGamePhase phase;
  final int? round;
  final bool isAutosave;
}

abstract class SaveRepository {
  Future<List<SaveSlotSummary>> listSlots();

  Future<void> saveSlot(String slotId, GameSaveV1 save);

  Future<GameSaveV1?> loadSlot(String slotId);

  Future<void> deleteSlot(String slotId);
}
