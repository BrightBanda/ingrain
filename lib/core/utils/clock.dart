abstract class Clock {
  const Clock();

  DateTime get now;
}

class SystemClock extends Clock {
  @override
  DateTime get now => DateTime.now();
}

class FixedClock extends Clock {
  final DateTime fixedTime;

  const FixedClock(this.fixedTime);

  @override
  DateTime get now => fixedTime;
}
