import '../../rule.dart';
import '../../util.dart';

/// `e164`: the value must be a phone number in the E.164 format: `+`, then 7
/// to 15 digits, the first one is not `0`. The output is the value as a
/// string.
LivrRule e164(List<Object?> args, RuleContext context) {
  if (args.isNotEmpty) {
    throw const LivrSchemaException('Rule [e164] takes no arguments');
  }
  return _e164;
}

RuleResult _e164(Object? value, Map<Object?, Object?> allValues) =>
    _check(value, _isE164);

// The string form of a number is checked and is the output. A boolean has
// no format: it fails with the code of the rule, even where its string form
// would pass ('true' is a host name, true is not)
RuleResult _check(Object? value, bool Function(String) isValid) {
  if (value is String) {
    if (value.isEmpty || isValid(value)) return RuleResult.valid;
    return RuleResult.error('WRONG_E164');
  }
  if (value is num && value.isFinite) {
    final str = livrToString(value);
    return isValid(str)
        ? RuleResult.value(str)
        : RuleResult.error('WRONG_E164');
  }
  if (value == null) return RuleResult.valid;
  return RuleResult.error(value is bool ? 'WRONG_E164' : 'FORMAT_ERROR');
}

bool _isE164(String str) {
  final length = str.length;
  if (length < 8 || length > 16 || str.codeUnitAt(0) != 0x2B) return false;
  if (str.codeUnitAt(1) == 0x30) return false; // "0"
  for (var i = 1; i < length; i++) {
    if (!_isDigit(str.codeUnitAt(i))) return false;
  }
  return true;
}

bool _isDigit(int char) => char >= 0x30 && char <= 0x39;
