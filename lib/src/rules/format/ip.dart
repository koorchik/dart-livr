import '../../rule.dart';
import '../../util.dart';

/// `ip`: the value must be an IPv4 or an IPv6 address; `{ip: 'v4'}` accepts
/// only IPv4, `{ip: 'v6'}` only IPv6. IPv4 numbers have no leading zeros
/// (`010.0.0.1` fails: some systems read it as octal); IPv6 is in the text
/// forms of RFC 4291, without a zone or brackets. The output is the value as
/// a string.
LivrRule ip(List<Object?> args, RuleContext context) {
  final version = _version(args, 'ip');
  return (value, allValues) => _check(value, (str) {
    final length = str.length;
    return (version != 6 && _isIPv4(str, 0, length)) ||
        (version != 4 && _isIPv6(str, 0, length));
  });
}

// 4 for "v4", 6 for "v6", 0 for both. Arguments after the version are
// ignored
int _version(List<Object?> args, String ruleName) {
  if (args.isEmpty) return 0;
  final version = args[0];
  if (version == 'v4' || version == 'v6') return version == 'v4' ? 4 : 6;
  throw LivrSchemaException(
    'Rule [$ruleName] expects no arguments, "v4" or "v6", got [$version]',
  );
}

// The string form of a number is checked and is the output. A boolean has
// no format: it fails with the code of the rule, even where its string form
// would pass ('true' is a host name, true is not)
RuleResult _check(Object? value, bool Function(String) isValid) {
  if (value is String) {
    if (value.isEmpty || isValid(value)) return RuleResult.valid;
    return RuleResult.error('WRONG_IP');
  }
  if (value is num && value.isFinite) {
    final str = livrToString(value);
    return isValid(str) ? RuleResult.value(str) : RuleResult.error('WRONG_IP');
  }
  if (value == null) return RuleResult.valid;
  return RuleResult.error(value is bool ? 'WRONG_IP' : 'FORMAT_ERROR');
}

// str[start, end) is four numbers 0-255 without leading zeros, separated by
// "."
bool _isIPv4(String str, int start, int end) {
  var parts = 0;
  var number = 0;
  var digits = 0;
  for (var i = start; i <= end; i++) {
    final char = i < end ? str.codeUnitAt(i) : 0x2E;
    if (char == 0x2E) {
      // "." or the end
      if (digits == 0 || ++parts > 4) return false;
      number = 0;
      digits = 0;
      continue;
    }
    final digit = char - 0x30;
    if (digit < 0 || digit > 9) return false;
    // A leading zero, or more than 255
    if (digits == 1 && number == 0) return false;
    number = number * 10 + digit;
    if (number > 255) return false;
    digits++;
  }
  return parts == 4;
}

// str[start, end) is an IPv6 address (RFC 4291, section 2.2): eight groups,
// or fewer with one "::" for one or more groups of zeros
bool _isIPv6(String str, int start, int end) {
  final gap = str.indexOf('::', start);
  if (gap == -1 || gap + 2 > end) {
    return _countGroups(str, start, end, true) == 8;
  }

  // A second "::" (":::" too) is ambiguous
  final secondGap = str.indexOf('::', gap + 1);
  if (secondGap != -1 && secondGap + 2 <= end) return false;

  final before = _countGroups(str, start, gap, false);
  final after = _countGroups(str, gap + 2, end, true);
  return before != -1 && after != -1 && before + after <= 7;
}

// The number of 16-bit groups in str[start, end): groups of 1-4 hexadecimal
// digits separated by ":", the last one may be an IPv4 address (two groups)
// at the end of the address. -1 for a wrong group
int _countGroups(String str, int start, int end, bool isAddressEnd) {
  if (start == end) return 0;

  var count = 0;
  var groupStart = start;
  for (var i = start; i < end; i++) {
    if (str.codeUnitAt(i) != 0x3A) continue; // ":"
    if (!_isHexGroup(str, groupStart, i)) return -1;
    count++;
    groupStart = i + 1;
  }

  if (_isHexGroup(str, groupStart, end)) return count + 1;
  if (isAddressEnd && _isIPv4(str, groupStart, end)) return count + 2;
  return -1;
}

bool _isHexGroup(String str, int start, int end) {
  if (end - start < 1 || end - start > 4) return false;
  for (var i = start; i < end; i++) {
    final char = str.codeUnitAt(i);
    final lower = char | 0x20;
    if (!((char >= 0x30 && char <= 0x39) || (lower >= 0x61 && lower <= 0x66))) {
      return false;
    }
  }
  return true;
}
