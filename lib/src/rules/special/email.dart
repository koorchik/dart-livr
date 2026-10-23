import '../../rule.dart';
import '../../util.dart';

/// `email`: the value must be an email address.
LivrRule email(List<Object?> args, RuleContext context) => _email;

RuleResult _email(Object? value, Map<Object?, Object?> allValues) {
  if (isNoValue(value)) return RuleResult.valid;
  if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');
  return _isEmail(livrToString(value))
      ? RuleResult.valid
      : RuleResult.error('WRONG_EMAIL');
}

// A scanner for the regular expression of the JavaScript implementation, which
// AOT-compiled Dart would run in a bytecode interpreter:
//
//   ^(?:[^<>()\[\]\\.,;:\s@"]+(?:\.[^<>()\[\]\\.,;:\s@"]+)*|"[^@\n\r  ]+")
//   @(?:\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\]|(?:[a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,})$
//
// Neither the local part nor the domain can contain "@", so the address has
// exactly one, and both parts are checked without backtracking
bool _isEmail(String str) {
  final at = str.indexOf('@');
  if (at < 1 || str.indexOf('@', at + 1) != -1) return false;

  return _isLocalPart(str, at) && _isDomain(str, at + 1);
}

// str[0, end): atoms separated by dots, or a quoted string
bool _isLocalPart(String str, int end) {
  if (str.codeUnitAt(0) == 0x22) {
    // '"': at least one character between the quotes, quotes included
    if (end < 3 || str.codeUnitAt(end - 1) != 0x22) return false;
    for (var i = 1; i < end - 1; i++) {
      final char = str.codeUnitAt(i);
      if (char == 0x0A || char == 0x0D || char == 0x2028 || char == 0x2029) {
        return false;
      }
    }
    return true;
  }

  var atomLength = 0;
  for (var i = 0; i < end; i++) {
    final char = str.codeUnitAt(i);
    if (char == 0x2E) {
      // "." between two atoms
      if (atomLength == 0) return false;
      atomLength = 0;
    } else if (_isSpecialInAtom(char)) {
      return false;
    } else {
      atomLength++;
    }
  }
  return atomLength > 0;
}

// <>()[]\,;:" and whitespace (\s of JavaScript regular expressions)
bool _isSpecialInAtom(int char) {
  if (char < 0x80) {
    return char <= 0x20 && (char == 0x20 || (char >= 0x09 && char <= 0x0D)) ||
        char == 0x3C || // <
        char == 0x3E || // >
        char == 0x28 || // (
        char == 0x29 || // )
        char == 0x5B || // [
        char == 0x5D || // ]
        char == 0x5C || // \
        char == 0x2C || // ,
        char == 0x3B || // ;
        char == 0x3A || // :
        char == 0x22; // "
  }
  return char == 0xA0 ||
      char == 0x1680 ||
      (char >= 0x2000 && char <= 0x200A) ||
      char == 0x2028 ||
      char == 0x2029 ||
      char == 0x202F ||
      char == 0x205F ||
      char == 0x3000 ||
      char == 0xFEFF;
}

// str[start, end of string): an IPv4 address in brackets, or two or more
// labels of letters, digits and "-", where the last one has 2+ letters only
bool _isDomain(String str, int start) {
  final end = str.length;
  if (start >= end) return false;

  if (str.codeUnitAt(start) == 0x5B) return _isIpLiteral(str, start, end);

  var labelLength = 0;
  var labels = 0;
  var isLetterLabel = true;
  for (var i = start; i < end; i++) {
    final char = str.codeUnitAt(i);
    if (char == 0x2E) {
      // "."
      if (labelLength == 0) return false;
      labels++;
      labelLength = 0;
      isLetterLabel = true;
    } else if (_isLetter(char)) {
      labelLength++;
    } else if (_isDigit(char) || char == 0x2D) {
      // a digit or "-"
      labelLength++;
      isLetterLabel = false;
    } else {
      return false;
    }
  }

  return labels >= 1 && labelLength >= 2 && isLetterLabel;
}

// "[1.2.3.4]": four groups of 1-3 digits
bool _isIpLiteral(String str, int start, int end) {
  if (str.codeUnitAt(end - 1) != 0x5D) return false;

  var groups = 0;
  var digits = 0;
  for (var i = start + 1; i < end - 1; i++) {
    final char = str.codeUnitAt(i);
    if (_isDigit(char)) {
      if (++digits > 3) return false;
    } else if (char == 0x2E && digits > 0 && groups < 3) {
      groups++;
      digits = 0;
    } else {
      return false;
    }
  }
  return groups == 3 && digits > 0;
}

bool _isLetter(int char) {
  final lower = char | 0x20;
  return lower >= 0x61 && lower <= 0x7A;
}

bool _isDigit(int char) => char >= 0x30 && char <= 0x39;
