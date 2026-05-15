import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/game_mode_menu_screen.dart';
import '../providers/dependencies.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final saveRepository = ref.watch(saveRepositoryProvider);

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            GameModeMenuScreen(saveRepository: saveRepository),
      ),
    ],
  );
});
