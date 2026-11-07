import '../../rule.dart';
import '../../util.dart';

/// `list_length`: the value must be a list with the given number of
/// elements: `{list_length: 2}`, `{list_length: [1, 10]}` (min and max) or
/// `{list_length: {'min': 1}}`. An empty list is a value, not an empty value.
LivrRule listLength(List<Object?> args, RuleContext context) {
  var min = 0;
  var max = -1; // no maximum
  final first = args.isEmpty ? null : args[0];

  // Arguments after the ones of the form are ignored
  if (first is Map<Object?, Object?>) {
    if (first.isEmpty) throw _argumentsError(args);
    for (final key in first.keys) {
      if (key != 'min' && key != 'max') {
        throw LivrSchemaException(
          'Rule [list_length] got an unknown option [$key]',
        );
      }
    }
    if (first.containsKey('min')) min = _length(first['min'], args);
    if (first.containsKey('max')) max = _length(first['max'], args);
  } else if (args.length == 1) {
    min = max = _length(first, args);
  } else if (args.length >= 2) {
    min = _length(args[0], args);
    max = _length(args[1], args);
  } else {
    throw _argumentsError(args);
  }

  if (max >= 0 && min > max) {
    throw LivrSchemaException(
      'Rule [list_length] got min [$min] greater than max [$max]',
    );
  }

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (value is! List) return RuleResult.error('FORMAT_ERROR');

    if (value.length < min) return RuleResult.error('TOO_FEW_ITEMS');
    if (max >= 0 && value.length > max) {
      return RuleResult.error('TOO_MANY_ITEMS');
    }
    return RuleResult.valid;
  };
}

// A non-negative integer: 2, 2.0 and '2'
int _length(Object? arg, List<Object?> args) {
  final number = _numberArg(arg);
  if (number != null && number >= 0 && number == number.truncateToDouble()) {
    return number.toInt();
  }
  throw _argumentsError(args);
}

LivrSchemaException _argumentsError(List<Object?> args) => LivrSchemaException(
  'Rule [list_length] expects a length, min and max, or an object with '
  '"min" and "max" (non-negative integers), got [$args]',
);

// A number argument: a number, or a string in the grammar of decimal,
// -?[0-9]+(\.[0-9]+)? ('2', '2.0', '02'; not ' 2', '1e1' or '0x40'), null
// for other values
num? _numberArg(Object? arg) {
  if (arg is num) return arg;
  if (arg is! String) return null;

  final length = arg.length;
  var i = length > 0 && arg.codeUnitAt(0) == 0x2D ? 1 : 0; // "-"
  final integerStart = i;
  while (i < length && _isDigit(arg.codeUnitAt(i))) {
    i++;
  }
  if (i == integerStart) return null;
  if (i < length) {
    if (arg.codeUnitAt(i) != 0x2E || i + 1 == length) return null; // "."
    for (i++; i < length; i++) {
      if (!_isDigit(arg.codeUnitAt(i))) return null;
    }
  }
  return parseNumber(arg);
}

bool _isDigit(int char) => char >= 0x30 && char <= 0x39;
