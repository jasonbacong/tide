import 'package:flutter/painting.dart';

/// Fonts are variable, so weight is set through the `wght` axis as well as fontWeight.
abstract final class TideType {
  static const sans = 'Inter';
  static const serif = 'Fraunces';

  static const _regular = [FontVariation('wght', 400)];
  static const _medium = [FontVariation('wght', 500)];
  static const _softSerif = [FontVariation('wght', 400), FontVariation('SOFT', 100)];

  static TextStyle greeting(Color color) => TextStyle(
      fontFamily: serif, fontSize: 28, height: 1.2, color: color, fontVariations: _softSerif);

  static TextStyle note(Color color) => TextStyle(
      fontFamily: serif,
      fontSize: 15,
      height: 1.4,
      fontStyle: FontStyle.italic,
      color: color,
      fontVariations: _softSerif);

  static TextStyle title(Color color) => TextStyle(
      fontFamily: sans,
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: color,
      fontVariations: _medium);

  static TextStyle body(Color color) =>
      TextStyle(fontFamily: sans, fontSize: 15, height: 1.45, color: color, fontVariations: _regular);

  static TextStyle label(Color color) => TextStyle(
      fontFamily: sans, fontSize: 12.5, letterSpacing: 0.2, color: color, fontVariations: _regular);
}
