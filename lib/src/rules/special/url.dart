import '../../rule.dart';
import '../../util.dart';

/// `url`: the value must be an http or https URL, with the protocol.
LivrRule url(List<Object?> args, RuleContext context) => _url;

// Letters of host labels: Latin letters and U+00A1-U+FFFF, so Unicode hosts
// (пример.рф) pass
const String _letter = 'a-z¡-￿';

// 1-63 characters, not starting or ending with "-". "." is not in a label, so
// labels do not backtrack into each other and a host is checked in linear time
const String _label =
    '[${_letter}0-9](?:[${_letter}0-9-]{0,61}[${_letter}0-9])?';

// The first byte is 1-223, the last one is not 255
const String _ipv4 =
    r'(?:[1-9]\d?|1\d\d|2[01]\d|22[0-3])(?:\.(?:1?\d{1,2}|2[0-4]\d|25[0-5])){2}'
    r'\.(?:[0-9]\d?|1\d\d|2[0-4]\d|25[0-4])';

// 0-65535 in 1-5 digits
const String _port =
    '(?:[0-9]{1,4}|[0-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])';

// The regular expression of the JavaScript implementation: optional user
// info, then an IPv4 address, labels with a top-level domain of 2-63 letters
// or localhost, no dot after the host. The lookahead, not in JavaScript,
// checks once that there is no whitespace (no part of a URL has it), so a
// value with whitespace fails without trying every split of the user info
// and the path, which both may contain "@"
final RegExp _urlRe = RegExp(
  '^https?://(?=\\S*\$)(?:\\S+@)?'
  '(?:$_ipv4|(?:$_label\\.)+[$_letter]{2,63}|localhost)'
  '(?::$_port)?(?:[/?#]\\S*)?\$',
  caseSensitive: false,
);

// Longer URLs do not work in some browsers
const int _maxUrlLength = 2083;

RuleResult _url(Object? value, Map<Object?, Object?> allValues) {
  if (isNoValue(value)) return RuleResult.valid;
  if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

  final str = livrToString(value);
  if (str.length < _maxUrlLength && _urlRe.hasMatch(str)) {
    return RuleResult.valid;
  }
  return RuleResult.error('WRONG_URL');
}
