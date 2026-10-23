import 'package:livr/livr.dart';
import 'package:test/test.dart';

void main() {
  test('valid', () {
    const result = RuleResult.valid;
    expect(result.isValid, isTrue);
    expect(result.isError, isFalse);
    expect(result.hasValue, isFalse);
    expect(result.valueOr('original'), 'original');
  });

  test('a new value, null included', () {
    for (final value in ['new', null, 0, <Object?>[]]) {
      final result = RuleResult.value(value);
      expect(result.isValid, isFalse);
      expect(result.isError, isFalse);
      expect(result.hasValue, isTrue);
      expect(result.value, value);
      expect(result.valueOr('original'), value);
    }
  });

  test('errors', () {
    final result = RuleResult.error({'zip': 'REQUIRED'});
    expect(result.isError, isTrue);
    expect(result.isValid, isFalse);
    expect(result.hasValue, isFalse);
    expect(result.error, {'zip': 'REQUIRED'});

    expect(RuleResult.error('TOO_SHORT').error, 'TOO_SHORT');
  });
}
