import 'package:flutter/material.dart';

const List<Color> _playerPalette = <Color>[
  Color(0xFF0D2B53), // Player 1: navy
  Color(0xFF7A1C2E), // Player 2: crimson
  Color(0xFF176B47), // Player 3: green
  Color(0xFF8A4B08), // Player 4: amber
];

Color playerColor(int playerId) {
  final normalized =
      ((playerId % _playerPalette.length) + _playerPalette.length) %
      _playerPalette.length;
  return _playerPalette[normalized];
}
