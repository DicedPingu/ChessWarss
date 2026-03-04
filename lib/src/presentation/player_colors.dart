import 'package:flutter/material.dart';

const List<Color> _playerPalette = <Color>[
  Color(0xFF005CB9), // Player 1: cobalt
  Color(0xFFC74800), // Player 2: vermilion
  Color(0xFF007A55), // Player 3: jungle
  Color(0xFF6A43A7), // Player 4: violet
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
