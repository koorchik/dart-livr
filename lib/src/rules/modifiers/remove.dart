import 'dart:typed_data';

import '../../rule.dart';
import '../../util.dart';

/// `remove`: Removes the given characters from the string. Numbers and booleans are
/// converted to strings, objects and lists are left as they are.
LivrRule remove(List<Object?> args, RuleContext context) {
  final chars = stringArg(args, 0, 'remove');

  // ASCII characters are looked up in a table, others in a set of code points
  final asciiChars = Uint8List(128);
  Set<int>? otherChars;
  for (final char in chars.runes) {
    if (char < 128) {
      asciiChars[char] = 1;
    } else {
      (otherChars ??= <int>{}).add(char);
    }
  }

  return (value, allValues) {
    if (isNoValue(value) || !isPrimitive(value)) return RuleResult.valid;

    return RuleResult.value(
        _remove(livrToString(value), asciiChars, otherChars));
  };
}

String _remove(String str, Uint8List asciiChars, Set<int>? otherChars) {
  final length = str.length;
  StringBuffer? buffer;
  var keptFrom = 0;
  var i = 0;

  while (i < length) {
    var char = str.codeUnitAt(i);
    var charLength = 1;
    if ((char & 0xFC00) == 0xD800 && i + 1 < length) {
      final low = str.codeUnitAt(i + 1);
      if ((low & 0xFC00) == 0xDC00) {
        char = 0x10000 + ((char - 0xD800) << 10) + (low - 0xDC00);
        charLength = 2;
      }
    }

    final isListed = char < 128
        ? asciiChars[char] == 1
        : otherChars != null && otherChars.contains(char);
    if (isListed) {
      // Copies the kept characters before this one at once
      (buffer ??= StringBuffer()).write(str.substring(keptFrom, i));
      keptFrom = i + charLength;
    }
    i += charLength;
  }

  if (buffer == null) return str;
  buffer.write(str.substring(keptFrom));
  return buffer.toString();
}
