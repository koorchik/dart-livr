import '../../rule.dart';
import '../../util.dart';

/// `semver`: the value must be a version of Semantic Versioning 2.0.0, like
/// `1.2.3`, `1.0.0-rc.1` or `1.0.0+build.5`, without a `v` prefix. The
/// output is the value as a string.
LivrRule semver(List<Object?> args, RuleContext context) {
  if (args.isNotEmpty) {
    throw const LivrSchemaException('Rule [semver] takes no arguments');
  }
  return _semver;
}

RuleResult _semver(Object? value, Map<Object?, Object?> allValues) =>
    _check(value, _isSemver);

// The string form of a number is checked and is the output. A boolean has
// no format: it fails with the code of the rule, even where its string form
// would pass ('true' is a host name, true is not)
RuleResult _check(Object? value, bool Function(String) isValid) {
  if (value is String) {
    if (value.isEmpty || isValid(value)) return RuleResult.valid;
    return RuleResult.error('WRONG_SEMVER');
  }
  if (value is num && value.isFinite) {
    final str = livrToString(value);
    return isValid(str)
        ? RuleResult.value(str)
        : RuleResult.error('WRONG_SEMVER');
  }
  if (value == null) return RuleResult.valid;
  return RuleResult.error(value is bool ? 'WRONG_SEMVER' : 'FORMAT_ERROR');
}

// version = core [ "-" pre-release ] [ "+" build ], a scanner for the
// grammar of semver.org
bool _isSemver(String str) {
  final length = str.length;

  // core = number "." number "." number, numbers without leading zeros
  var i = 0;
  for (var part = 0; part < 3; part++) {
    if (part > 0) {
      if (i >= length || str.codeUnitAt(i) != 0x2E) return false; // "."
      i++;
    }
    final start = i;
    while (i < length && _isDigit(str.codeUnitAt(i))) {
      i++;
    }
    if (i == start || (i - start > 1 && str.codeUnitAt(start) == 0x30)) {
      return false;
    }
  }

  if (i < length && str.codeUnitAt(i) == 0x2D) {
    // "-" pre-release: identifiers separated by ".", a numeric one without
    // leading zeros
    do {
      i++;
      final start = i;
      var isNumeric = true;
      while (i < length && _isIdentifierChar(str.codeUnitAt(i))) {
        if (!_isDigit(str.codeUnitAt(i))) isNumeric = false;
        i++;
      }
      if (i == start) return false;
      if (isNumeric && i - start > 1 && str.codeUnitAt(start) == 0x30) {
        return false;
      }
    } while (i < length && str.codeUnitAt(i) == 0x2E);
  }

  if (i < length && str.codeUnitAt(i) == 0x2B) {
    // "+" build: identifiers separated by "."
    do {
      i++;
      final start = i;
      while (i < length && _isIdentifierChar(str.codeUnitAt(i))) {
        i++;
      }
      if (i == start) return false;
    } while (i < length && str.codeUnitAt(i) == 0x2E);
  }

  return i == length;
}

// A digit, a letter or "-"
bool _isIdentifierChar(int char) =>
    _isDigit(char) || _isLetter(char) || char == 0x2D;

bool _isDigit(int char) => char >= 0x30 && char <= 0x39;

bool _isLetter(int char) {
  final lower = char | 0x20;
  return lower >= 0x61 && lower <= 0x7A;
}
