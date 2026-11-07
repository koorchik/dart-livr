import '../../rule.dart';
import '../../util.dart';

/// `iban`: the value must be an IBAN (ISO 13616): 2 letters `A-Z`, 2 digits
/// and 11-30 letters `A-Z` or digits, with a valid checksum (mod 97). It is
/// checked as it is: spaces are not removed and lowercase letters fail. No
/// per-country lengths. The output is the value as a string.
LivrRule iban(List<Object?> args, RuleContext context) {
  if (args.isNotEmpty) {
    throw const LivrSchemaException('Rule [iban] takes no arguments');
  }
  return _iban;
}

RuleResult _iban(Object? value, Map<Object?, Object?> allValues) =>
    _check(value, _isIban);

// The string form of a number is checked and is the output. A boolean has
// no format: it fails with the code of the rule, even where its string form
// would pass ('true' is a host name, true is not)
RuleResult _check(Object? value, bool Function(String) isValid) {
  if (value is String) {
    if (value.isEmpty || isValid(value)) return RuleResult.valid;
    return RuleResult.error('WRONG_IBAN');
  }
  if (value is num && value.isFinite) {
    final str = livrToString(value);
    return isValid(str)
        ? RuleResult.value(str)
        : RuleResult.error('WRONG_IBAN');
  }
  if (value == null) return RuleResult.valid;
  return RuleResult.error(value is bool ? 'WRONG_IBAN' : 'FORMAT_ERROR');
}

bool _isIban(String str) {
  final length = str.length;
  if (length < 15 || length > 34) return false;
  if (!_isUpper(str.codeUnitAt(0)) || !_isUpper(str.codeUnitAt(1))) {
    return false;
  }
  if (!_isDigit(str.codeUnitAt(2)) || !_isDigit(str.codeUnitAt(3))) {
    return false;
  }

  // The first four characters moved to the end, a letter is two digits
  // (A = 10 ... Z = 35): the number modulo 97 is 1. The remainder is
  // computed one character at a time, so it stays small
  var remainder = 0;
  for (var i = 0; i < length; i++) {
    final char = str.codeUnitAt((i + 4) % length);
    if (_isDigit(char)) {
      remainder = (remainder * 10 + char - 0x30) % 97;
    } else if (_isUpper(char)) {
      remainder = (remainder * 100 + char - 0x37) % 97;
    } else {
      return false;
    }
  }
  return remainder == 1;
}

bool _isUpper(int char) => char >= 0x41 && char <= 0x5A;

bool _isDigit(int char) => char >= 0x30 && char <= 0x39;
