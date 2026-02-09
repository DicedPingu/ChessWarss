import 'package:flutter/material.dart';

import 'presentation/prototype_game_screen.dart';

class ChessWarssApp extends StatelessWidget {
  const ChessWarssApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChessWarss Prototype',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F6A5A)),
      ),
      home: const PrototypeGameScreen(),
    );
  }
}
