import '../../rule.dart';
import '../../util.dart';

/// `hex`: the value must be hexadecimal digits `0-9`, `a-f` or `A-F`, without
/// a `0x` prefix. The output is the value as a string.
LivrRule hex(List<Object?> args, RuleContext context) {
  if (args.isNotEmpty) {
    throw const LivrSchemaException('Rule [hex] takes no arguments');
  }
  return _hex;
}

RuleResult _hex(Object? value, Map<Object?, Object?> allValues) =>
    _check(value, _isHexString);

// The string form of a number is checked and is the output. A boolean has
// no format: it fails with the code of the rule, even where its string form
// would pass ('true' is a host name, true is not)
RuleResult _check(Object? value, bool Function(String) isValid) {
  if (value is String) {
    if (value.isEmpty || isValid(value)) return RuleResult.valid;
    return RuleResult.error('WRONG_HEX');
  }
  if (value is num && value.isFinite) {
    final str = livrToString(value);
    return isValid(str) ? RuleResult.value(str) : RuleResult.error('WRONG_HEX');
  }
  if (value == null) return RuleResult.valid;
  return RuleResult.error(value is bool ? 'WRONG_HEX' : 'FORMAT_ERROR');
}

bool _isHexString(String str) => _isHex(str, 0, str.length);

// str[start, end) is HEX
bool _isHex(String str, int start, int end) {
  for (var i = start; i < end; i++) {
    if (!_isHexChar(str.codeUnitAt(i))) return false;
  }
  return true;
}

// 0-9, A-F or a-f
bool _isHexChar(int char) {
  final lower = char | 0x20;
  return (char >= 0x30 && char <= 0x39) || (lower >= 0x61 && lower <= 0x66);
}
