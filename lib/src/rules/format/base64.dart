import '../../rule.dart';
import '../../util.dart';

/// `base64`: the value must be Base64 (RFC 4648): the alphabet `A-Za-z0-9+/`,
/// a length that is a multiple of 4, and the padding `=` or `==` only at the
/// end. `{base64: 'url'}` takes the URL-safe alphabet `A-Za-z0-9-_`, with
/// the padding complete or absent. No whitespace. The output is the value as
/// a string.
LivrRule base64(List<Object?> args, RuleContext context) {
  if (args.isEmpty) return _base64;
  // Arguments after the variant are ignored
  if (args[0] == 'url') return _base64Url;
  throw LivrSchemaException(
    'Rule [base64] expects no arguments or "url", got [${args[0]}]',
  );
}

RuleResult _base64(Object? value, Map<Object?, Object?> allValues) =>
    _check(value, _isBase64);

RuleResult _base64Url(Object? value, Map<Object?, Object?> allValues) =>
    _check(value, _isBase64Url);

// The string form of a number is checked and is the output. A boolean has
// no format: it fails with the code of the rule, even where its string form
// would pass ('true' is a host name, true is not)
RuleResult _check(Object? value, bool Function(String) isValid) {
  if (value is String) {
    if (value.isEmpty || isValid(value)) return RuleResult.valid;
    return RuleResult.error('WRONG_BASE64');
  }
  if (value is num && value.isFinite) {
    final str = livrToString(value);
    return isValid(str)
        ? RuleResult.value(str)
        : RuleResult.error('WRONG_BASE64');
  }
  if (value == null) return RuleResult.valid;
  return RuleResult.error(value is bool ? 'WRONG_BASE64' : 'FORMAT_ERROR');
}

// The standard alphabet, the padding is required. The unused bits of the
// last character are not checked
bool _isBase64(String str) {
  final length = str.length;
  if (length % 4 != 0) return false;

  final end = length - _padding(str);
  for (var i = 0; i < end; i++) {
    final char = str.codeUnitAt(i);
    if (!_isAlphanumeric(char) && char != 0x2B && char != 0x2F) return false;
  }
  return true;
}

// The URL-safe alphabet: no padding and a length of 0, 2 or 3 modulo 4, or
// the complete padding
bool _isBase64Url(String str) {
  final length = str.length;
  final padding = _padding(str);
  if (padding == 0 ? length % 4 == 1 : length % 4 != 0) return false;

  final end = length - padding;
  for (var i = 0; i < end; i++) {
    final char = str.codeUnitAt(i);
    if (!_isAlphanumeric(char) && char != 0x2D && char != 0x5F) return false;
  }
  return true;
}

// The number of "=" at the end: 0, 1 or 2. More is not padding, so the
// characters before them fail as not in the alphabet
int _padding(String str) {
  final length = str.length;
  if (length < 2 || str.codeUnitAt(length - 1) != 0x3D) return 0;
  return str.codeUnitAt(length - 2) == 0x3D ? 2 : 1;
}

// A-Z, a-z or 0-9
bool _isAlphanumeric(int char) {
  final lower = char | 0x20;
  return (lower >= 0x61 && lower <= 0x7A) || (char >= 0x30 && char <= 0x39);
}
