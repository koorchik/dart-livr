import '../../rule.dart';
import '../../util.dart';

/// `credit_card`: the value must be a card number of 12-19 digits (ISO/IEC
/// 7812) with a valid Luhn checksum, without card network detection. It is
/// checked as it is: spaces and dashes are not removed. The output is the
/// value as a string.
LivrRule creditCard(List<Object?> args, RuleContext context) {
  if (args.isNotEmpty) {
    throw const LivrSchemaException('Rule [credit_card] takes no arguments');
  }
  return _creditCard;
}

RuleResult _creditCard(Object? value, Map<Object?, Object?> allValues) =>
    _check(value, _isCreditCard);

// The string form of a number is checked and is the output. A boolean has
// no format: it fails with the code of the rule, even where its string form
// would pass ('true' is a host name, true is not)
RuleResult _check(Object? value, bool Function(String) isValid) {
  if (value is String) {
    if (value.isEmpty || isValid(value)) return RuleResult.valid;
    return RuleResult.error('WRONG_CREDIT_CARD_NUMBER');
  }
  if (value is num && value.isFinite) {
    final str = livrToString(value);
    return isValid(str)
        ? RuleResult.value(str)
        : RuleResult.error('WRONG_CREDIT_CARD_NUMBER');
  }
  if (value == null) return RuleResult.valid;
  return RuleResult.error(
    value is bool ? 'WRONG_CREDIT_CARD_NUMBER' : 'FORMAT_ERROR',
  );
}

bool _isCreditCard(String str) =>
    str.length >= 12 &&
    str.length <= 19 &&
    _isDigits(str) &&
    _hasLuhnChecksum(str);

// Luhn mod 10 of the digits: every second digit from the right is doubled
bool _hasLuhnChecksum(String digits) {
  var sum = 0;
  var isDoubled = false;
  for (var i = digits.length - 1; i >= 0; i--) {
    var digit = digits.codeUnitAt(i) - 0x30;
    if (isDoubled) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
    isDoubled = !isDoubled;
  }
  return sum % 10 == 0;
}

bool _isDigits(String str) {
  for (var i = 0; i < str.length; i++) {
    final char = str.codeUnitAt(i);
    if (char < 0x30 || char > 0x39) return false;
  }
  return true;
}
