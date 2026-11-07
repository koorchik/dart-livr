import '../../rule.dart';
import '../../util.dart';

/// `digits`: the value must be one or more ASCII digits `0-9`. Leading zeros
/// are kept, and the output is a string: `'007'` stays `'007'`, `7` becomes
/// `'7'`.
LivrRule digits(List<Object?> args, RuleContext context) {
  if (args.isNotEmpty) {
    throw const LivrSchemaException('Rule [digits] takes no arguments');
  }
  return _digits;
}

RuleResult _digits(Object? value, Map<Object?, Object?> allValues) {
  if (value is String) {
    return _isDigits(value) ? RuleResult.valid : RuleResult.error('NOT_DIGITS');
  }
  if (value == null) return RuleResult.valid;
  if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

  // The string form of a number or a boolean
  final str = livrToString(value);
  return _isDigits(str)
      ? RuleResult.value(str)
      : RuleResult.error('NOT_DIGITS');
}

// Only ASCII digits; '' passes, it is an empty value
bool _isDigits(String str) {
  for (var i = 0; i < str.length; i++) {
    final char = str.codeUnitAt(i);
    if (char < 0x30 || char > 0x39) return false;
  }
  return true;
}
