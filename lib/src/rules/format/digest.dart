import '../../rule.dart';
import '../../util.dart';

/// `digest`: the value must be a hexadecimal digest of one of the given
/// algorithms, `md5` (32 digits), `sha1` (40), `sha256` (64), `sha384` (96)
/// or `sha512` (128): `{digest: 'sha256'}`, `{digest: ['md5', 'sha1']}`. The
/// output is the value as a string.
LivrRule digest(List<Object?> args, RuleContext context) {
  if (args.isEmpty) {
    throw const LivrSchemaException(
      'Rule [digest] expects one or more algorithms',
    );
  }

  final lengths = List<int>.generate(args.length, (i) {
    final length = _hexLengths[args[i]];
    if (length == null) {
      throw LivrSchemaException(
        'Rule [digest] got an unknown algorithm [${args[i]}]',
      );
    }
    return length;
  }, growable: false);

  return (value, allValues) => _check(value, (str) {
    final length = str.length;
    if (!lengths.contains(length)) return false;
    for (var i = 0; i < length; i++) {
      if (!_isHexChar(str.codeUnitAt(i))) return false;
    }
    return true;
  });
}

// The lengths of the digests in hexadecimal digits
const Map<Object?, int> _hexLengths = {
  'md5': 32,
  'sha1': 40,
  'sha256': 64,
  'sha384': 96,
  'sha512': 128,
};

// The string form of a number is checked and is the output. A boolean has
// no format: it fails with the code of the rule, even where its string form
// would pass ('true' is a host name, true is not)
RuleResult _check(Object? value, bool Function(String) isValid) {
  if (value is String) {
    if (value.isEmpty || isValid(value)) return RuleResult.valid;
    return RuleResult.error('WRONG_DIGEST');
  }
  if (value is num && value.isFinite) {
    final str = livrToString(value);
    return isValid(str)
        ? RuleResult.value(str)
        : RuleResult.error('WRONG_DIGEST');
  }
  if (value == null) return RuleResult.valid;
  return RuleResult.error(value is bool ? 'WRONG_DIGEST' : 'FORMAT_ERROR');
}

// 0-9, A-F or a-f
bool _isHexChar(int char) {
  final lower = char | 0x20;
  return (char >= 0x30 && char <= 0x39) || (lower >= 0x61 && lower <= 0x66);
}
