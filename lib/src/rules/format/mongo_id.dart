import '../../rule.dart';
import '../../util.dart';

/// `mongo_id`: the value must be a BSON ObjectId, 24 hexadecimal digits. The
/// output is the value as a string.
LivrRule mongoId(List<Object?> args, RuleContext context) {
  if (args.isNotEmpty) {
    throw const LivrSchemaException('Rule [mongo_id] takes no arguments');
  }
  return _mongoId;
}

RuleResult _mongoId(Object? value, Map<Object?, Object?> allValues) =>
    _check(value, _isMongoId);

// The string form of a number is checked and is the output. A boolean has
// no format: it fails with the code of the rule, even where its string form
// would pass ('true' is a host name, true is not)
RuleResult _check(Object? value, bool Function(String) isValid) {
  if (value is String) {
    if (value.isEmpty || isValid(value)) return RuleResult.valid;
    return RuleResult.error('WRONG_MONGO_ID');
  }
  if (value is num && value.isFinite) {
    final str = livrToString(value);
    return isValid(str)
        ? RuleResult.value(str)
        : RuleResult.error('WRONG_MONGO_ID');
  }
  if (value == null) return RuleResult.valid;
  return RuleResult.error(value is bool ? 'WRONG_MONGO_ID' : 'FORMAT_ERROR');
}

bool _isMongoId(String str) => str.length == 24 && _isHex(str, 0, 24);

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
