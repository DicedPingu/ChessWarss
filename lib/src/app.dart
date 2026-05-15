import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'routing/router.dart';

class ChessWarssApp extends ConsumerWidget {
  const ChessWarssApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'ChessWarss',
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
