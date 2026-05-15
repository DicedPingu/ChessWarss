import 'package:flutter/material.dart';

const List<Color> _playerPalette = <Color>[
  Color(0xFFDC143C), // Player 1: crimson (Roman red)
  Color(0xFFDAA520), // Player 2: goldenrod (Roman gold)
  Color(0xFF8B4513), // Player 3: saddle brown (earthy)
  Color(0xFF2F4F4F), // Player 4: dark slate gray (neutral)
];

Color playerColor(int playerId) {
  final normalized =
      ((playerId % _playerPalette.length) + _playerPalette.length) %
      _playerPalette.length;
  return _playerPalette[normalized];
}

Color playerOnColor(int playerId) {
  final brightness = ThemeData.estimateBrightnessForColor(
    playerColor(playerId),
  );
  return brightness == Brightness.dark ? Colors.white : Colors.black;
}
