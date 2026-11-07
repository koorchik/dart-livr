import '../../rule.dart';
import '../../util.dart';

/// `hostname`: the value must be a host name (RFC 1123): labels of 1-63
/// letters, digits and `-`, not starting or ending with `-`, separated by
/// `.`, at most 253 characters, no trailing dot. A single label like
/// `localhost` passes. The last label is not all digits, so an IPv4 address
/// is not a host name. The output is the value as a string.
LivrRule hostname(List<Object?> args, RuleContext context) {
  if (args.isNotEmpty) {
    throw const LivrSchemaException('Rule [hostname] takes no arguments');
  }
  return _hostname;
}

RuleResult _hostname(Object? value, Map<Object?, Object?> allValues) =>
    _check(value, _isHostname);

// The string form of a number is checked and is the output. A boolean has
// no format: it fails with the code of the rule, even where its string form
// would pass ('true' is a host name, true is not)
RuleResult _check(Object? value, bool Function(String) isValid) {
  if (value is String) {
    if (value.isEmpty || isValid(value)) return RuleResult.valid;
    return RuleResult.error('WRONG_HOSTNAME');
  }
  if (value is num && value.isFinite) {
    final str = livrToString(value);
    return isValid(str)
        ? RuleResult.value(str)
        : RuleResult.error('WRONG_HOSTNAME');
  }
  if (value == null) return RuleResult.valid;
  return RuleResult.error(value is bool ? 'WRONG_HOSTNAME' : 'FORMAT_ERROR');
}

bool _isHostname(String str) {
  final length = str.length;
  if (length > 253) return false;

  var labelStart = 0;
  var isAllDigits = true;
  for (var i = 0; i <= length; i++) {
    final char = i < length ? str.codeUnitAt(i) : 0x2E;
    if (char == 0x2E) {
      // "." or the end: a label of 1-63 characters without "-" at its ends
      final labelLength = i - labelStart;
      if (labelLength < 1 || labelLength > 63) return false;
      if (str.codeUnitAt(labelStart) == 0x2D || str.codeUnitAt(i - 1) == 0x2D) {
        return false;
      }
      labelStart = i + 1;
      if (i == length) return !isAllDigits;
      isAllDigits = true;
    } else if (_isDigit(char)) {
      continue;
    } else if (_isLetter(char) || char == 0x2D) {
      isAllDigits = false;
    } else {
      return false;
    }
  }
  return true;
}

bool _isDigit(int char) => char >= 0x30 && char <= 0x39;

bool _isLetter(int char) {
  final lower = char | 0x20;
  return lower >= 0x61 && lower <= 0x7A;
}
