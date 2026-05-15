import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/save/save_repository.dart';
import '../application/save/local_json_save_repository.dart';

final saveRepositoryProvider = Provider<SaveRepository>((ref) {
  return const LocalJsonSaveRepository();
});
