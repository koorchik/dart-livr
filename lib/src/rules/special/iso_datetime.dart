import 'dart:typed_data';

import '../../rule.dart';
import '../../util.dart';

/// `iso_datetime`: the value must be a date and a time with an offset,
/// `YYYY-MM-DDTHH:MM[:SS[.fraction]]` and `Z` or `+HH:MM`/`-HH:MM`. The
/// output is the instant in UTC with three fraction digits, cut off, not
/// rounded: `'2026-10-29T10:00:00.123456+02:00'` becomes
/// `'2026-10-29T08:00:00.123Z'`.
///
/// With bounds, `{iso_datetime: {'min': '2026-01-01T09:00:00Z', 'max':
/// 'tomorrow'}}`, the instant must be in the range, both bounds included. A
/// bound is a datetime, a date (the start of the UTC day as `min`, its end
/// as `max`), or `'today'`, `'yesterday'` or `'tomorrow'`, the UTC days of
/// the clock of the validator. Arguments after the options are ignored.
LivrRule isoDatetime(List<Object?> args, RuleContext context) {
  if (args.isEmpty) return _isoDatetime;

  final options = args[0];
  if (options is! Map<Object?, Object?>) {
    throw LivrSchemaException(
      'Rule [iso_datetime] expects no arguments or an object with "min" and '
      '"max", got [$options]',
    );
  }
  for (final key in options.keys) {
    if (key != 'min' && key != 'max') {
      throw LivrSchemaException(
        'Rule [iso_datetime] got an unknown option [$key]',
      );
    }
  }

  // A fixed bound is the key of an instant (see _key), a relative one is the
  // number of days from the current date
  final min = options.containsKey('min')
      ? _parseBound(options['min'], isMax: false)
      : null;
  final max = options.containsKey('max')
      ? _parseBound(options['max'], isMax: true)
      : null;
  if (min == null && max == null) return _isoDatetime;

  final minKey = min?.key ?? -_maxKey;
  final maxKey = max?.key ?? _maxKey;
  final minDays = min?.days;
  final maxDays = max?.days;

  // No value could pass. The keys are cut to milliseconds. A fixed and a
  // relative bound are not compared: the result depends on the day, and
  // that can be intended
  if (min != null &&
      max != null &&
      (minDays == null
          ? maxDays == null && minKey > maxKey
          : maxDays != null && minDays > maxDays)) {
    throw LivrSchemaException(
      'Rule [iso_datetime] got min [${options['min']}] later than max '
      '[${options['max']}]',
    );
  }

  final clock = minDays != null || maxDays != null ? context.clock : null;

  return (value, allValues) {
    if (value is! String) return _notString(value);
    if (value.isEmpty) return RuleResult.valid;

    final form = _parse(value);
    if (form < 0 || _utcYear < 0 || _utcYear > 9999) {
      return RuleResult.error('WRONG_DATETIME');
    }
    final key = _key();

    if (clock == null) {
      if (key < minKey) return RuleResult.error('DATETIME_TOO_EARLY');
      if (key > maxKey) return RuleResult.error('DATETIME_TOO_LATE');
    } else {
      // One clock read per value: the current date in UTC, never in the
      // local time zone
      final today = _dayNumber(clock());
      final minBound = minDays == null ? minKey : _relativeKey(today, minDays);
      if (key < minBound) return RuleResult.error('DATETIME_TOO_EARLY');
      final maxBound = maxDays == null
          ? maxKey
          : _relativeKey(today, maxDays) + _dayMs - 1;
      if (key > maxBound) return RuleResult.error('DATETIME_TOO_LATE');
    }

    return form == _outputForm ? RuleResult.valid : RuleResult.value(_format());
  };
}

RuleResult _isoDatetime(Object? value, Map<Object?, Object?> allValues) {
  if (value is! String) return _notString(value);
  if (value.isEmpty) return RuleResult.valid;

  final form = _parse(value);
  if (form == _outputForm) return RuleResult.valid;
  if (form < 0 || _utcYear < 0 || _utcYear > 9999) {
    return RuleResult.error('WRONG_DATETIME');
  }
  return RuleResult.value(_format());
}

// A value that is not a string: empty, a number or a boolean (never a
// datetime), or not a primitive value
RuleResult _notString(Object? value) {
  if (value == null) return RuleResult.valid;
  return RuleResult.error(
    isPrimitive(value) ? 'WRONG_DATETIME' : 'FORMAT_ERROR',
  );
}

const int _dayMs = 86400000;

// Above every key, exact as a double on the web too
const int _maxKey = 9007199254740991;

const Map<String, int> _relativeDays = {
  'yesterday': -1,
  'today': 0,
  'tomorrow': 1,
};

({int? key, int? days}) _parseBound(Object? bound, {required bool isMax}) {
  if (bound is String) {
    final days = _relativeDays[bound];
    if (days != null) return (key: null, days: days);

    if (bound.length == 10) {
      // A date: the start or the end of the UTC day
      if (_parse('${bound}T00:00Z') > 0) {
        return (key: isMax ? _key() + _dayMs - 1 : _key(), days: null);
      }
    } else if (_parse(bound) > 0) {
      // An instant of any year: it is only compared, never written out
      return (key: _key(), days: null);
    }
  }

  // "current" of livr-extra-rules is "today" in LIVR 2.5
  throw LivrSchemaException(
    'Rule [iso_datetime] expects a datetime with an offset, a date '
    'YYYY-MM-DD, "today", "yesterday" or "tomorrow" as '
    '[${isMax ? 'max' : 'min'}], got [$bound]'
    '${bound == 'current' ? ', use "today" instead of "current"' : ''}',
  );
}

// The UTC fields of the last datetime that _parse() read, cut to
// milliseconds. Top-level variables instead of a record: no allocation per
// value
int _utcYear = 0;
int _utcMonth = 0;
int _utcDay = 0;
int _utcMinutes = 0; // of the day
int _utcSeconds = 0;
int _utcMs = 0;

// _parse() of a string in the form of the output, YYYY-MM-DDTHH:MM:SS.sssZ
const int _outputForm = 2;

// Parses YYYY-MM-DD "T" HH ":" MM [ ":" SS [ "." 1*9DIGIT ] ] ( "Z" /
// ( "+" / "-" ) HH ":" MM ) into the UTC fields. Returns -1 for any other
// string, _outputForm for a string in the form of the output, 1 otherwise.
// A scanner instead of a regular expression with groups, which AOT-compiled
// Dart runs in a bytecode interpreter
int _parse(String str) {
  final length = str.length;
  if (length < 17 ||
      str.codeUnitAt(4) != 0x2D || // "-"
      str.codeUnitAt(7) != 0x2D ||
      str.codeUnitAt(10) != 0x54 || // "T"
      str.codeUnitAt(13) != 0x3A) {
    // ":"
    return -1;
  }

  final century = _digits2(str, 0);
  final yearOfCentury = _digits2(str, 2);
  var month = _digits2(str, 5);
  var day = _digits2(str, 8);
  final hours = _digits2(str, 11);
  final minutes = _digits2(str, 14);
  if (century < 0 ||
      yearOfCentury < 0 ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      hours < 0 ||
      hours > 23 ||
      minutes < 0 ||
      minutes > 59) {
    return -1;
  }
  var year = century * 100 + yearOfCentury;
  if (day > 28 && day > _daysInMonth(year, month)) return -1;

  var seconds = 0;
  var ms = 0;
  var index = 16;
  var char = str.codeUnitAt(16);

  if (char == 0x3A) {
    // ":SS"
    if (length < 20) return -1;
    seconds = _digits2(str, 17);
    if (seconds < 0 || seconds > 59) return -1;

    index = 19;
    char = str.codeUnitAt(19);
    if (char == 0x2E) {
      // "." and 1-9 digits: the first three are milliseconds, the others
      // are cut off
      index = 20;
      while (index < length && index < 29) {
        final digit = str.codeUnitAt(index) - 0x30;
        if (digit < 0 || digit > 9) break;
        if (index < 23) ms = ms * 10 + digit;
        index++;
      }
      if (index == 20 || index >= length) return -1;
      if (index == 21) {
        ms *= 100;
      } else if (index == 22) {
        ms *= 10;
      }
      char = str.codeUnitAt(index);
    }
  }

  var offset = 0; // minutes east of UTC
  if (char == 0x5A) {
    // "Z"
    if (index + 1 != length) return -1;
  } else if (char == 0x2B || char == 0x2D) {
    // "+" or "-"
    if (index + 6 != length || str.codeUnitAt(index + 3) != 0x3A) return -1;
    final offsetHours = _digits2(str, index + 1);
    final offsetMinutes = _digits2(str, index + 4);
    if (offsetHours < 0 ||
        offsetHours > 23 ||
        offsetMinutes < 0 ||
        offsetMinutes > 59) {
      return -1;
    }
    offset = offsetHours * 60 + offsetMinutes;
    if (char == 0x2D) offset = -offset;
  } else {
    return -1;
  }

  // An offset moves the time by less than a day, so at most to the next or
  // the previous day
  var minutesOfDay = hours * 60 + minutes - offset;
  if (minutesOfDay < 0) {
    minutesOfDay += 1440;
    if (--day == 0) {
      if (--month == 0) {
        month = 12;
        year--;
      }
      day = _daysInMonth(year, month);
    }
  } else if (minutesOfDay >= 1440) {
    minutesOfDay -= 1440;
    if (++day > 28 && day > _daysInMonth(year, month)) {
      day = 1;
      if (++month == 13) {
        month = 1;
        year++;
      }
    }
  }

  _utcYear = year;
  _utcMonth = month;
  _utcDay = day;
  _utcMinutes = minutesOfDay;
  _utcSeconds = seconds;
  _utcMs = ms;

  // "Z" at 23 only after seconds and three fraction digits
  return index == 23 && char == 0x5A ? _outputForm : 1;
}

// Two ASCII digits at index as a number, -1 when they are not digits
int _digits2(String str, int index) {
  final high = str.codeUnitAt(index) - 0x30;
  final low = str.codeUnitAt(index + 1) - 0x30;
  return high >= 0 && high <= 9 && low >= 0 && low <= 9 ? high * 10 + low : -1;
}

// Days in each month, index 0 is January
const List<int> _monthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

int _daysInMonth(int year, int month) {
  if (month != 2) return _monthDays[month - 1];
  return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 ? 29 : 28;
}

// The key of the last parsed datetime: a number in the order of time,
// (year * 512 + month * 32 + day) * _dayMs plus the milliseconds of the day,
// without the calendar arithmetic. Exact on the web too: the keys of the
// years 0000-9999 are below 2^49
int _key() =>
    (_utcYear * 512 + _utcMonth * 32 + _utcDay) * _dayMs +
    (_utcMinutes * 60 + _utcSeconds) * 1000 +
    _utcMs;

// The output form of the last parsed datetime, from character codes
final Uint8List _buffer = Uint8List(24);

String _format() {
  final buffer = _buffer;
  final year = _utcYear;
  final hours = _utcMinutes ~/ 60;
  final minutes = _utcMinutes - hours * 60;
  final ms = _utcMs;

  buffer[0] = 0x30 + year ~/ 1000;
  buffer[1] = 0x30 + year ~/ 100 % 10;
  buffer[2] = 0x30 + year ~/ 10 % 10;
  buffer[3] = 0x30 + year % 10;
  buffer[4] = 0x2D;
  buffer[5] = 0x30 + _utcMonth ~/ 10;
  buffer[6] = 0x30 + _utcMonth % 10;
  buffer[7] = 0x2D;
  buffer[8] = 0x30 + _utcDay ~/ 10;
  buffer[9] = 0x30 + _utcDay % 10;
  buffer[10] = 0x54;
  buffer[11] = 0x30 + hours ~/ 10;
  buffer[12] = 0x30 + hours % 10;
  buffer[13] = 0x3A;
  buffer[14] = 0x30 + minutes ~/ 10;
  buffer[15] = 0x30 + minutes % 10;
  buffer[16] = 0x3A;
  buffer[17] = 0x30 + _utcSeconds ~/ 10;
  buffer[18] = 0x30 + _utcSeconds % 10;
  buffer[19] = 0x2E;
  buffer[20] = 0x30 + ms ~/ 100;
  buffer[21] = 0x30 + ms ~/ 10 % 10;
  buffer[22] = 0x30 + ms % 10;
  buffer[23] = 0x5A;
  return String.fromCharCodes(buffer);
}

// Days since 1970-01-01 in UTC, rounded down
int _dayNumber(DateTime now) {
  final ms = now.millisecondsSinceEpoch;
  final days = ms ~/ _dayMs;
  return ms < 0 && days * _dayMs != ms ? days - 1 : days;
}

// The keys of the start of yesterday, today and tomorrow of the day number
// in _cachedDay. They change once a day, so all rules share them
int? _cachedDay;
final List<int> _cachedKeys = List<int>.filled(3, 0);

int _relativeKey(int today, int days) {
  if (today != _cachedDay) {
    for (var i = 0; i < 3; i++) {
      final date = DateTime.fromMillisecondsSinceEpoch(
        (today + i - 1) * _dayMs,
        isUtc: true,
      );
      _cachedKeys[i] = (date.year * 512 + date.month * 32 + date.day) * _dayMs;
    }
    _cachedDay = today;
  }
  return _cachedKeys[days + 1];
}
