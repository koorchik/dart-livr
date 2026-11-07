import '../../rule.dart';
import '../../util.dart';

/// `iso_date`: the value must be an ISO 8601 date without time, like
/// `2014-08-14`.
///
/// With bounds, `{iso_date: {'min': '2026-01-01', 'max': 'today'}}`, the date
/// must be in the range, both bounds included. A bound is a date or
/// `'today'`, `'yesterday'` or `'tomorrow'`: the current UTC date of the
/// clock of the validator, one day before it or after it. The first
/// argument, if any, must be an options object (LIVR 2.0 ignored any
/// argument, so `{iso_date: 'today'}` checked nothing); arguments after it
/// are ignored. `{iso_date: null}` is the plain `iso_date`, as in 2.0. Dates
/// are in the proleptic Gregorian calendar: `1582-10-10` is valid,
/// `1500-02-29` is not.
LivrRule isoDate(List<Object?> args, RuleContext context) {
  if (args.isEmpty || (args.length == 1 && args[0] == null)) return _isoDate;

  final options = args[0];
  if (options is! Map<Object?, Object?>) {
    throw LivrSchemaException(
      'Rule [iso_date] expects no arguments or an object with "min" and '
      '"max", got [$options]',
    );
  }
  for (final key in options.keys) {
    if (key != 'min' && key != 'max') {
      throw LivrSchemaException(
        'Rule [iso_date] got an unknown option [$key]'
        '${key == 'format' ? ', use iso_datetime for datetimes' : ''}',
      );
    }
  }

  // A fixed bound is a key of a date (_dateKey), a relative one is the
  // number of days from the current date
  final min = options.containsKey('min')
      ? _parseBound(options['min'], 'min')
      : null;
  final max = options.containsKey('max')
      ? _parseBound(options['max'], 'max')
      : null;
  if (min == null && max == null) return _isoDate;

  final minKey = min?.key ?? -1;
  final maxKey = max?.key ?? _maxKey;
  final minDays = min?.days;
  final maxDays = max?.days;

  // No value could pass. A fixed and a relative bound are not compared: the
  // result depends on the day, and that can be intended
  if (min != null &&
      max != null &&
      (minDays == null
          ? maxDays == null && minKey > maxKey
          : maxDays != null && minDays > maxDays)) {
    throw LivrSchemaException(
      'Rule [iso_date] got min [${options['min']}] later than max '
      '[${options['max']}]',
    );
  }

  if (minDays == null && maxDays == null) {
    return (value, allValues) {
      if (value is! String) return _notString(value);
      if (value.isEmpty) return RuleResult.valid;

      final key = _dateKey(value);
      if (key < 0) return RuleResult.error('WRONG_DATE');
      if (key < minKey) return RuleResult.error('DATE_TOO_EARLY');
      if (key > maxKey) return RuleResult.error('DATE_TOO_LATE');
      return RuleResult.valid;
    };
  }

  final clock = context.clock;
  return (value, allValues) {
    if (value is! String) return _notString(value);
    if (value.isEmpty) return RuleResult.valid;

    final key = _dateKey(value);
    if (key < 0) return RuleResult.error('WRONG_DATE');

    // One clock read per value: the current date in UTC, never in the local
    // time zone
    final today = _dayNumber(clock());
    if (key < (minDays == null ? minKey : _relativeKey(today, minDays))) {
      return RuleResult.error('DATE_TOO_EARLY');
    }
    if (key > (maxDays == null ? maxKey : _relativeKey(today, maxDays))) {
      return RuleResult.error('DATE_TOO_LATE');
    }
    return RuleResult.valid;
  };
}

RuleResult _isoDate(Object? value, Map<Object?, Object?> allValues) {
  if (value is! String) return _notString(value);
  if (value.isEmpty) return RuleResult.valid;
  return _dateKey(value) < 0
      ? RuleResult.error('WRONG_DATE')
      : RuleResult.valid;
}

// A value that is not a string: empty, a number or a boolean (never a date),
// or not a primitive value
RuleResult _notString(Object? value) {
  if (value == null) return RuleResult.valid;
  return RuleResult.error(isPrimitive(value) ? 'WRONG_DATE' : 'FORMAT_ERROR');
}

const int _maxKey = 1 << 30;
const int _dayMs = 86400000;
const Map<String, int> _relativeDays = {
  'yesterday': -1,
  'today': 0,
  'tomorrow': 1,
};

({int? key, int? days}) _parseBound(Object? bound, String name) {
  if (bound is String) {
    final days = _relativeDays[bound];
    if (days != null) return (key: null, days: days);

    final key = _dateKey(bound);
    if (key >= 0) return (key: key, days: null);
  }

  // "current" of livr-extra-rules is "today" in LIVR 2.5
  throw LivrSchemaException(
    'Rule [iso_date] expects a date YYYY-MM-DD, "today", "yesterday" or '
    '"tomorrow" as [$name], got [$bound]'
    '${bound == 'current' ? ', use "today" instead of "current"' : ''}',
  );
}

// Days in each month, index 0 is January
const List<int> _daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

// YYYY-MM-DD as a number in the order of dates (year * 512 + month * 32 +
// day), or -1 when it is not a valid calendar date
int _dateKey(String str) {
  if (str.length != 10 ||
      str.codeUnitAt(4) != 0x2D ||
      str.codeUnitAt(7) != 0x2D) {
    return -1;
  }

  final year = _digits(str, 0, 4);
  final month = _digits(str, 5, 7);
  final day = _digits(str, 8, 10);
  if (year < 0 || month < 1 || month > 12 || day < 1) return -1;

  if (day > 28) {
    final isLeapYear = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
    final maxDay = month == 2 && isLeapYear ? 29 : _daysInMonth[month - 1];
    if (day > maxDay) return -1;
  }
  return year * 512 + month * 32 + day;
}

// The number from the digits of str[start, end), or -1 if one is not a digit
int _digits(String str, int start, int end) {
  var number = 0;
  for (var i = start; i < end; i++) {
    final digit = str.codeUnitAt(i) - 0x30;
    if (digit < 0 || digit > 9) return -1;
    number = number * 10 + digit;
  }
  return number;
}

// Days since 1970-01-01 in UTC, rounded down
int _dayNumber(DateTime now) {
  final ms = now.millisecondsSinceEpoch;
  final days = ms ~/ _dayMs;
  return ms < 0 && days * _dayMs != ms ? days - 1 : days;
}

// The keys of yesterday, today and tomorrow of the day number in _cachedDay.
// They change once a day, so all rules share them
int? _cachedDay;
final List<int> _cachedKeys = List<int>.filled(3, 0);

int _relativeKey(int today, int days) {
  if (today != _cachedDay) {
    for (var i = 0; i < 3; i++) {
      final date = DateTime.fromMillisecondsSinceEpoch(
        (today + i - 1) * _dayMs,
        isUtc: true,
      );
      _cachedKeys[i] = date.year * 512 + date.month * 32 + date.day;
    }
    _cachedDay = today;
  }
  return _cachedKeys[days + 1];
}
