import 'package:tide/data/clock.dart';

class FakeClock implements Clock {
  FakeClock(this._now);
  DateTime _now;

  @override
  DateTime now() => _now;

  void set(DateTime value) => _now = value;
  void advance(Duration by) => _now = _now.add(by);
}
