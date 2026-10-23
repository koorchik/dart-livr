import '../../rule.dart';
import '../../util.dart';

/// `equal_to_field`: the value must be equal to the value of another field.
/// Values are compared as strings: `'10'` and `10` are equal. A missing
/// field is not equal to any value.
LivrRule equalToField(List<Object?> args, RuleContext context) {
  final field = stringArg(args, 0, 'equal_to_field');

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (!isPrimitive(value)) return RuleResult.error('FORMAT_ERROR');

    final otherValue = allValues[field];
    if (otherValue is String && value is String) {
      return otherValue == value
          ? RuleResult.valid
          : RuleResult.error('FIELDS_NOT_EQUAL');
    }
    if (!isPrimitive(otherValue) ||
        livrToString(otherValue) != livrToString(value)) {
      return RuleResult.error('FIELDS_NOT_EQUAL');
    }
    return RuleResult.valid;
  };
}
