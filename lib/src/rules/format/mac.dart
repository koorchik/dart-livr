import '../../rule.dart';
import '../../util.dart';

/// `mac`: the value must be a MAC address, six pairs of hexadecimal digits
/// (48 bits, MAC-48 or EUI-48) separated by `:` or by `-`, the same
/// separator everywhere: `00:1A:2b:3c:4D:5e`. `{mac: 64}` takes eight pairs
/// (EUI-64). The output is the value as a string.
LivrRule mac(List<Object?> args, RuleContext context) {
  // Arguments after the first one are ignored. A string with a number is
  // the number
  final arg = args.isEmpty ? 48 : args[0];
  final bits = _numberArg(arg);
  if (bits != 48 && bits != 64) {
    throw LivrSchemaException(
      'Rule [mac] expects no arguments, 48 or 64, got [$arg]',
    );
  }

  // Pairs and separators: 6 pairs are 17 characters, 8 pairs 23
  final length = bits == 48 ? 17 : 23;
  return (value, allValues) => _check(value, (str) {
    if (str.length != length) return false;

    final separator = str.codeUnitAt(2);
    if (separator != 0x3A && separator != 0x2D) return false; // ":" or "-"
    for (var i = 0; i < length; i++) {
      final char = str.codeUnitAt(i);
      if (i % 3 == 2) {
        if (char != separator) return false;
      } else if (!_isHexChar(char)) {
        return false;
      }
    }
    return true;
  });
}

// The string form of a number is checked and is the output. A boolean has
// no format: it fails with the code of the rule, even where its string form
// would pass ('true' is a host name, true is not)
RuleResult _check(Object? value, bool Function(String) isValid) {
  if (value is String) {
    if (value.isEmpty || isValid(value)) return RuleResult.valid;
    return RuleResult.error('WRONG_MAC');
  }
  if (value is num && value.isFinite) {
    final str = livrToString(value);
    return isValid(str) ? RuleResult.value(str) : RuleResult.error('WRONG_MAC');
  }
  if (value == null) return RuleResult.valid;
  return RuleResult.error(value is bool ? 'WRONG_MAC' : 'FORMAT_ERROR');
}

// 0-9, A-F or a-f
bool _isHexChar(int char) {
  final lower = char | 0x20;
  return (char >= 0x30 && char <= 0x39) || (lower >= 0x61 && lower <= 0x66);
}

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
