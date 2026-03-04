import 'package:flutter/foundation.dart';

@immutable
class GameSettingsSnapshot {
  const GameSettingsSnapshot({
    required this.animationSpeed,
    required this.aiDelayMs,
    required this.reducedEffects,
  });

  static const GameSettingsSnapshot defaults = GameSettingsSnapshot(
    animationSpeed: 1.0,
    aiDelayMs: 750,
    reducedEffects: false,
  );

  final double animationSpeed;
  final int aiDelayMs;
  final bool reducedEffects;

  GameSettingsSnapshot copyWith({
    double? animationSpeed,
    int? aiDelayMs,
    bool? reducedEffects,
  }) {
    return GameSettingsSnapshot(
      animationSpeed: animationSpeed ?? this.animationSpeed,
      aiDelayMs: aiDelayMs ?? this.aiDelayMs,
      reducedEffects: reducedEffects ?? this.reducedEffects,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'animationSpeed': animationSpeed,
      'aiDelayMs': aiDelayMs,
      'reducedEffects': reducedEffects,
    };
  }

  factory GameSettingsSnapshot.fromJson(Map<String, dynamic> json) {
    return GameSettingsSnapshot(
      animationSpeed: switch (json['animationSpeed']) {
        final num n => n.toDouble(),
        _ => defaults.animationSpeed,
      },
      aiDelayMs: switch (json['aiDelayMs']) {
        final num n => n.toInt(),
        _ => defaults.aiDelayMs,
      },
      reducedEffects: json['reducedEffects'] == true,
    );
  }
}
