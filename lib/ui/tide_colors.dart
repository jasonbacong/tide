import 'package:flutter/material.dart';

@immutable
class TideColors extends ThemeExtension<TideColors> {
  const TideColors({
    required this.background,
    required this.card,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.warm,
    required this.soft,
  });

  final Color background;
  final Color card;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color warm;
  final Color soft;

  static const light = TideColors(
    background: Color(0xFFF6EFE6),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF3A332C),
    muted: Color(0xFF8A7F72),
    accent: Color(0xFF6FA3A0),
    warm: Color(0xFFD08A6A),
    soft: Color(0xFFE6DED2),
  );

  static const dark = TideColors(
    background: Color(0xFF1F1C19),
    card: Color(0xFF2A2622),
    ink: Color(0xFFEFE7DC),
    muted: Color(0xFFA89C8E),
    accent: Color(0xFF7FB5B1),
    warm: Color(0xFFDB9B7C),
    soft: Color(0xFF3A342E),
  );

  /// Mood 1 (low) → 5 (high). Same in both modes.
  static const mood = [
    Color(0xFFB7A6C9),
    Color(0xFF9DB4CF),
    Color(0xFFC9C2B4),
    Color(0xFFE3C27E),
    Color(0xFFE59A77),
  ];

  @override
  TideColors copyWith({
    Color? background,
    Color? card,
    Color? ink,
    Color? muted,
    Color? accent,
    Color? warm,
    Color? soft,
  }) =>
      TideColors(
        background: background ?? this.background,
        card: card ?? this.card,
        ink: ink ?? this.ink,
        muted: muted ?? this.muted,
        accent: accent ?? this.accent,
        warm: warm ?? this.warm,
        soft: soft ?? this.soft,
      );

  @override
  TideColors lerp(ThemeExtension<TideColors>? other, double t) {
    if (other is! TideColors) return this;
    return TideColors(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      warm: Color.lerp(warm, other.warm, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
    );
  }
}

extension TideColorsX on BuildContext {
  TideColors get tide => Theme.of(this).extension<TideColors>()!;
}
