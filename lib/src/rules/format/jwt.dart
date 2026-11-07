import '../../rule.dart';
import '../../util.dart';

/// `jwt`: the value must have the structure of a JSON Web Token (the JWS
/// compact serialization): three base64url segments without padding,
/// separated by `.`, the last one may be empty (an unsecured JWT). The
/// segments are not decoded or verified. The output is the value as a
/// string.
LivrRule jwt(List<Object?> args, RuleContext context) {
  if (args.isNotEmpty) {
    throw const LivrSchemaException('Rule [jwt] takes no arguments');
  }
  return _jwt;
}

RuleResult _jwt(Object? value, Map<Object?, Object?> allValues) =>
    _check(value, _isJwt);

// The string form of a number is checked and is the output. A boolean has
// no format: it fails with the code of the rule, even where its string form
// would pass ('true' is a host name, true is not)
RuleResult _check(Object? value, bool Function(String) isValid) {
  if (value is String) {
    if (value.isEmpty || isValid(value)) return RuleResult.valid;
    return RuleResult.error('WRONG_JWT');
  }
  if (value is num && value.isFinite) {
    final str = livrToString(value);
    return isValid(str) ? RuleResult.value(str) : RuleResult.error('WRONG_JWT');
  }
  if (value == null) return RuleResult.valid;
  return RuleResult.error(value is bool ? 'WRONG_JWT' : 'FORMAT_ERROR');
}

bool _isJwt(String str) {
  final length = str.length;
  var segments = 0;
  var segmentStart = 0;
  for (var i = 0; i <= length; i++) {
    final char = i < length ? str.codeUnitAt(i) : 0x2E;
    if (char == 0x2E) {
      // "." or the end. No bytes give a base64url length of 1 modulo 4
      final segmentLength = i - segmentStart;
      if (segmentLength % 4 == 1) return false;
      if (segmentLength == 0 && segments < 2) return false;
      if (++segments > 3) return false;
      segmentStart = i + 1;
    } else if (!_isBase64UrlChar(char)) {
      return false;
    }
  }
  return segments == 3;
}

// A-Z, a-z, 0-9, "-" or "_"
bool _isBase64UrlChar(int char) {
  final lower = char | 0x20;
  return (lower >= 0x61 && lower <= 0x7A) ||
      (char >= 0x30 && char <= 0x39) ||
      char == 0x2D ||
      char == 0x5F;
}
