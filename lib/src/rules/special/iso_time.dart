import '../../rule.dart';
import '../../util.dart';

/// `iso_time`: the value must be a time of day without an offset, `HH:MM`,
/// `HH:MM:SS` or `HH:MM:SS.fraction` with 1-9 digits, as
/// `<input type="time">` sends it. The value is not changed.
///
/// With bounds, `{iso_time: {'min': '09:00', 'max': '18:00'}}`, the time must
/// be in the range, both bounds included. With `min` after `max` the range
/// goes over midnight: `{'min': '22:00', 'max': '06:00'}` accepts `23:30` and
/// `05:59`, and a time between them gets the error of the nearer bound.
LivrRule isoTime(List<Object?> args, RuleContext context) {
  if (args.isEmpty) return _isoTime;

  // Arguments after the options are ignored
  final options = args[0];
  if (options is! Map<Object?, Object?>) {
    throw LivrSchemaException(
      'Rule [iso_time] expects no arguments or an object with "min" and '
      '"max", got [$options]',
    );
  }
  for (final key in options.keys) {
    if (key != 'min' && key != 'max') {
      throw LivrSchemaException('Rule [iso_time] got an unknown option [$key]');
    }
  }

  final min = options.containsKey('min')
      ? _parseBound(options['min'], 'min')
      : null;
  final max = options.containsKey('max')
      ? _parseBound(options['max'], 'max')
      : null;
  if (min == null && max == null) return _isoTime;

  if (min == null || max == null || min <= max) {
    final minTime = min ?? 0;
    final maxTime = max ?? _dayNs;

    return (value, allValues) {
      if (value is! String) return _notString(value);
      if (value.isEmpty) return RuleResult.valid;

      final time = _parseTime(value);
      if (time < 0) return RuleResult.error('WRONG_TIME');
      if (time < minTime) return RuleResult.error('TIME_TOO_EARLY');
      if (time > maxTime) return RuleResult.error('TIME_TOO_LATE');
      return RuleResult.valid;
    };
  }

  // Over midnight: a time in the gap between max and min gets the error of
  // the nearer bound, TIME_TOO_EARLY exactly in the middle
  return (value, allValues) {
    if (value is! String) return _notString(value);
    if (value.isEmpty) return RuleResult.valid;

    final time = _parseTime(value);
    if (time < 0) return RuleResult.error('WRONG_TIME');
    if (time >= min || time <= max) return RuleResult.valid;
    return RuleResult.error(
      time - max < min - time ? 'TIME_TOO_LATE' : 'TIME_TOO_EARLY',
    );
  };
}

RuleResult _isoTime(Object? value, Map<Object?, Object?> allValues) {
  if (value is! String) return _notString(value);
  if (value.isEmpty) return RuleResult.valid;
  return _parseTime(value) < 0
      ? RuleResult.error('WRONG_TIME')
      : RuleResult.valid;
}

// A value that is not a string: empty, a number or a boolean (never a time),
// or not a primitive value
RuleResult _notString(Object? value) {
  if (value == null) return RuleResult.valid;
  return RuleResult.error(isPrimitive(value) ? 'WRONG_TIME' : 'FORMAT_ERROR');
}

int _parseBound(Object? bound, String name) {
  final time = bound is String ? _parseTime(bound) : -1;
  if (time < 0) {
    throw LivrSchemaException(
      'Rule [iso_time] expects a time HH:MM[:SS[.fraction]] as [$name], '
      'got [$bound]',
    );
  }
  return time;
}

// Nanoseconds in a day: above every time
const int _dayNs = 86400000000000;

// 10^(9 - digits): the nanoseconds of the last of 1-9 fraction digits
const List<int> _fractionUnits = [
  100000000,
  10000000,
  1000000,
  100000,
  10000,
  1000,
  100,
  10,
  1,
];

// HH:MM, HH:MM:SS or HH:MM:SS.fraction as nanoseconds since midnight, -1 for
// any other string. Exact on the web too, below 2^53, so all nine fraction
// digits count
int _parseTime(String str) {
  final length = str.length;
  if (length != 5 && length != 8 && (length < 10 || length > 18)) return -1;

  final hours = _digits2(str, 0);
  final minutes = _digits2(str, 3);
  if (str.codeUnitAt(2) != 0x3A ||
      hours < 0 ||
      hours > 23 ||
      minutes < 0 ||
      minutes > 59) {
    return -1;
  }

  var seconds = hours * 3600 + minutes * 60;
  if (length == 5) return seconds * 1000000000;

  final secondsOfMinute = _digits2(str, 6);
  if (str.codeUnitAt(5) != 0x3A ||
      secondsOfMinute < 0 ||
      secondsOfMinute > 59) {
    return -1;
  }
  seconds += secondsOfMinute;
  if (length == 8) return seconds * 1000000000;

  if (str.codeUnitAt(8) != 0x2E) return -1; // "."
  var fraction = 0;
  for (var i = 9; i < length; i++) {
    final digit = str.codeUnitAt(i) - 0x30;
    if (digit < 0 || digit > 9) return -1;
    fraction = fraction * 10 + digit;
  }
  return seconds * 1000000000 + fraction * _fractionUnits[length - 10];
}

// Two ASCII digits at index as a number, -1 when they are not digits
int _digits2(String str, int index) {
  final high = str.codeUnitAt(index) - 0x30;
  final low = str.codeUnitAt(index + 1) - 0x30;
  return high >= 0 && high <= 9 && low >= 0 && low <= 9 ? high * 10 + low : -1;
}
