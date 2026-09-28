import 'dart:ui' show Brightness, Color;

enum PartOfDay { morning, afternoon, evening, night }

PartOfDay periodFor(DateTime local) {
  final h = local.hour;
  if (h >= 5 && h < 12) return PartOfDay.morning;
  if (h >= 12 && h < 17) return PartOfDay.afternoon;
  if (h >= 17 && h < 22) return PartOfDay.evening;
  return PartOfDay.night;
}

const _tintStrength = 0.06;

/// Blends the base background a few percent toward a mood for the time of day.
Color tintedBackground(Color base, PartOfDay period, Brightness brightness) {
  final tint = switch ((period, brightness)) {
    (PartOfDay.afternoon, _) => null,
    (PartOfDay.morning, Brightness.light) => const Color(0xFFE6F2F4),
    (PartOfDay.morning, Brightness.dark) => const Color(0xFF3B4C52),
    (PartOfDay.evening, Brightness.light) => const Color(0xFFF3C6A5),
    (PartOfDay.evening, Brightness.dark) => const Color(0xFF5C3F2E),
    (PartOfDay.night, Brightness.light) => const Color(0xFF9FA8B8),
    (PartOfDay.night, Brightness.dark) => const Color(0xFF0D1117),
  };
  return tint == null ? base : Color.lerp(base, tint, _tintStrength)!;
}
