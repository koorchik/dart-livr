import '../../rule.dart';
import '../../util.dart';

/// `iso_date`: the value must be an ISO 8601 date without time, like
/// `2014-08-14`.
LivrRule isoDate(List<Object?> args, RuleContext context) => _isoDate;

// Days in each month, index 0 is January
const List<int> _daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

RuleResult _isoDate(Object? value, Map<Object?, Object?> allValues) {
  if (isNoValue(value)) return RuleResult.valid;
  if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');
  if (value is! String || value.length != 10) {
    return RuleResult.error('WRONG_DATE');
  }

  // YYYY-MM-DD
  if (value.codeUnitAt(4) != 0x2D || value.codeUnitAt(7) != 0x2D) {
    return RuleResult.error('WRONG_DATE');
  }
  final year = _digits(value, 0, 4);
  final month = _digits(value, 5, 7);
  final day = _digits(value, 8, 10);
  if (year < 0 || month < 1 || month > 12 || day < 1) {
    return RuleResult.error('WRONG_DATE');
  }

  final isLeapYear = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
  final maxDay = month == 2 && isLeapYear ? 29 : _daysInMonth[month - 1];
  return day > maxDay ? RuleResult.error('WRONG_DATE') : RuleResult.valid;
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
