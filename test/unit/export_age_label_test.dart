import 'package:flutter_test/flutter_test.dart';
import 'package:tide/features/settings/backup_section.dart';

void main() {
  final now = DateTime(2026, 9, 28, 9);
  test('labels', () {
    expect(exportAgeLabel(null, now), 'Not exported yet');
    expect(exportAgeLabel(DateTime(2026, 9, 28, 8), now), 'Last exported today');
    expect(exportAgeLabel(DateTime(2026, 9, 27, 23), now), 'Last exported yesterday');
    expect(exportAgeLabel(DateTime(2026, 8, 19), now), 'Last exported 40 days ago');
  });
}
