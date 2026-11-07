import '../../rule.dart';
import '../../util.dart';

/// `uuid`: the value must be a UUID (RFC 9562), `8-4-4-4-12` hexadecimal
/// digits. Without arguments the version is 1-8 and the variant is RFC 9562,
/// and the nil and the max UUID pass too. With versions, `{uuid: 'v4'}` or
/// `{uuid: ['v4', 'v7']}`, the version must be one of them. The output is
/// the value as a string.
LivrRule uuid(List<Object?> args, RuleContext context) {
  if (args.isEmpty) return _anyUuid;

  // Allowed version digits as bits: "v4" is 1 << 4
  var allowedVersions = 0;
  for (final version in args) {
    final digit =
        version is String &&
            version.length == 2 &&
            version.codeUnitAt(0) ==
                0x76 // "v"
        ? version.codeUnitAt(1) - 0x30
        : 0;
    if (digit < 1 || digit > 8) {
      throw LivrSchemaException(
        'Rule [uuid] expects versions "v1"-"v8", got [$version]',
      );
    }
    allowedVersions |= 1 << digit;
  }

  return (value, allValues) => _check(value, (str) {
    if (!_isUuid(str) || !_hasVariant(str)) return false;
    final version = str.codeUnitAt(14) - 0x30;
    return version >= 1 &&
        version <= 8 &&
        allowedVersions & (1 << version) != 0;
  });
}

RuleResult _anyUuid(Object? value, Map<Object?, Object?> allValues) =>
    _check(value, _isAnyUuid);

// The string form of a number is checked and is the output. A boolean has
// no format: it fails with the code of the rule, even where its string form
// would pass ('true' is a host name, true is not)
RuleResult _check(Object? value, bool Function(String) isValid) {
  if (value is String) {
    if (value.isEmpty || isValid(value)) return RuleResult.valid;
    return RuleResult.error('WRONG_UUID');
  }
  if (value is num && value.isFinite) {
    final str = livrToString(value);
    return isValid(str)
        ? RuleResult.value(str)
        : RuleResult.error('WRONG_UUID');
  }
  if (value == null) return RuleResult.valid;
  return RuleResult.error(value is bool ? 'WRONG_UUID' : 'FORMAT_ERROR');
}

// A version 1-8 with the variant, or the nil or the max UUID
bool _isAnyUuid(String str) {
  if (!_isUuid(str)) return false;
  final version = str.codeUnitAt(14);
  if (version >= 0x31 && version <= 0x38 && _hasVariant(str)) return true;
  return _isAll(str, 0x30) || _isAll(str, 0x66);
}

// 8-4-4-4-12 hexadecimal digits
bool _isUuid(String str) {
  if (str.length != 36) return false;
  for (var i = 0; i < 36; i++) {
    final char = str.codeUnitAt(i);
    if (i == 8 || i == 13 || i == 18 || i == 23) {
      if (char != 0x2D) return false; // "-"
    } else if (!_isHexChar(char)) {
      return false;
    }
  }
  return true;
}

// The variant of RFC 9562: 8, 9, a or b at index 19
bool _hasVariant(String str) {
  final variant = str.codeUnitAt(19) | 0x20;
  return variant == 0x38 ||
      variant == 0x39 ||
      variant == 0x61 ||
      variant == 0x62;
}

// Every hexadecimal digit is the given lowercase digit (0 or f), in any case
bool _isAll(String str, int digit) {
  for (var i = 0; i < 36; i++) {
    if (i == 8 || i == 13 || i == 18 || i == 23) continue;
    if (str.codeUnitAt(i) | 0x20 != digit) return false;
  }
  return true;
}

// 0-9, A-F or a-f
bool _isHexChar(int char) {
  final lower = char | 0x20;
  return (char >= 0x30 && char <= 0x39) || (lower >= 0x61 && lower <= 0x66);
}
