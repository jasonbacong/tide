import 'package:flutter/material.dart';

/// Curated outline icons for habits. Keys are stored in the database.
const habitIcons = <String, IconData>{
  'book': Icons.menu_book_outlined,
  'water': Icons.water_drop_outlined,
  'run': Icons.directions_run,
  'walk': Icons.directions_walk,
  'yoga': Icons.self_improvement,
  'calm': Icons.spa_outlined,
  'sleep': Icons.bedtime_outlined,
  'greens': Icons.eco_outlined,
  'pill': Icons.medication_outlined,
  'journal': Icons.edit_note,
  'music': Icons.music_note_outlined,
  'sun': Icons.wb_sunny_outlined,
  'bike': Icons.directions_bike,
  'swim': Icons.pool,
  'gym': Icons.fitness_center,
  'code': Icons.code,
  'language': Icons.translate,
  'plant': Icons.local_florist_outlined,
  'tidy': Icons.cleaning_services_outlined,
  'screen': Icons.do_not_disturb_on_outlined,
  'teeth': Icons.clean_hands_outlined,
  'kind': Icons.favorite_border,
  'no-drink': Icons.no_drinks_outlined,
  'call': Icons.call_outlined,
};

IconData iconFor(String key) => habitIcons[key] ?? Icons.circle_outlined;
