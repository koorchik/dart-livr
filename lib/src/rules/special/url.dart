import '../../rule.dart';
import '../../util.dart';

/// `url`: the value must be an http or https URL, with the protocol.
LivrRule url(List<Object?> args, RuleContext context) => _url;

// The regular expression of the JavaScript implementation
final RegExp _urlRe = RegExp(
  r'^(?:(?:http|https)://)(?:\S+(?::\S*)?@)?(?:'
  r'(?:(?:[1-9]\d?|1\d\d|2[0-1]\d|22[0-3])(?:\.(?:1?\d{1,2}|2[0-4]\d|25[0-5])){2}(?:\.(?:[0-9]\d?|1\d\d|2[0-4]\d|25[0-4]))'
  r'|(?:(?:[a-z¡-￿0-9]-*)*[a-z¡-￿0-9]+)(?:\.(?:[a-z¡-￿0-9]-*)*[a-z¡-￿0-9]+)*(?:\.(?:[a-z¡-￿]{2,}))'
  r')\.?|localhost)(?::\d{2,5})?(?:[/?#]\S*)?$',
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
