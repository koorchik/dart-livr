import 'package:livr/livr.dart';
import 'package:test/test.dart';

const Map<String, Object?> userSchema = {
  'email': ['required', 'email', 'to_lc'],
  'age': ['required', 'positive_integer'],
  'nickname': {'max_length': 20},
  'address': {
    'nested_object': {'city': 'required'},
  },
};

// A type described by hand: an extension type over the output map, no copy
extension type UserView(Map<String, Object?> _) {
  String get email => _['email'] as String;
  int get age => _['age'] as int;
  String? get nickname => _['nickname'] as String?;
  AddressView get address => AddressView(_['address'] as Map<String, Object?>);
}

extension type AddressView(Map<String, Object?> _) {
  String get city => _['city'] as String;
}

// A model class, like the ones of json_serializable or freezed
final class User {
  User({required this.email, required this.age});

  factory User.fromJson(Map<String, Object?> json) =>
      User(email: json['email'] as String, age: json['age'] as int);

  final String email;
  final int age;
}

const Map<String, Object?> validInput = {
  'email': 'John@Example.com',
  'age': '25',
  'address': {'city': 'Kyiv', 'zip': 'dropped'},
  'extra': 'dropped',
};

void main() {
  group('an extension type', () {
    final validator = Validator(userSchema, UserView.new);

    test('the output has the type of the view', () {
      // The static types: the assignments do not compile with other types
      final ValidationResult<UserView> result = validator.validate(validInput);

      // Exhaustive without a default case: ValidationFailure is a
      // ValidationResult<Never>
      switch (result) {
        case ValidationSuccess(:final output):
          final String email = output.email;
          final int age = output.age;
          expect(email, 'john@example.com');
          expect(age, 25);
          expect(output.nickname, isNull);
          expect(output.address.city, 'Kyiv');
        case ValidationFailure():
          fail('the input is valid');
      }
    });

    test('the type is inferred from the conversion function', () {
      // Validator<UserView>: the assignment does not compile with another type
      final Validator<UserView> typedValidator = validator;
      expect(typedValidator.validateOrThrow(validInput).age, 25);
    });

    test('the view is the output map itself', () {
      final output = validator.validateOrThrow(validInput);
      expect(output as Object, isA<Map<String, Object?>>());
      expect(output as Object, {
        'email': 'john@example.com',
        'age': 25,
        'address': {'city': 'Kyiv'},
      });
    });

    test('errors are the same as without a type', () {
      final result = validator.validate({'email': 'x', 'age': 0});
      expect(result, isA<ValidationFailure>());
      expect((result as ValidationFailure).errors, {
        'email': 'WRONG_EMAIL',
        'age': 'NOT_POSITIVE_INTEGER',
      });
      expect(
        () => validator.validateOrThrow('not a map'),
        throwsA(
          isA<LivrValidationException>().having(
            (e) => e.errors,
            'errors',
            'FORMAT_ERROR',
          ),
        ),
      );
    });
  });

  group('a model class', () {
    final validator = Validator(userSchema, User.fromJson);

    test('converts the output', () {
      final User user = validator.validateOrThrow(validInput);
      expect(user.email, 'john@example.com');
      expect(user.age, 25);
    });

    test('a conversion that does not match the schema throws', () {
      final wrongValidator = Validator({'age': 'string'}, User.fromJson);
      expect(
        () => wrongValidator.validate({'age': 25}),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('untyped validators', () {
    final validator = Validator.untyped(userSchema);

    test('return the output as a map', () {
      final ValidationResult<Map<String, Object?>> result = validator.validate(
        validInput,
      );
      expect((result as ValidationSuccess<Map<String, Object?>>).output, {
        'email': 'john@example.com',
        'age': 25,
        'address': {'city': 'Kyiv'},
      });
    });
  });

  group('ValidationResult.map()', () {
    final validator = Validator.untyped(userSchema);

    test('converts a valid result', () {
      final result = validator.validate(validInput).map(User.fromJson);
      expect((result as ValidationSuccess<User>).output.age, 25);
    });

    test('returns an invalid result as it is, without converting', () {
      var isCalled = false;
      final failure = validator.validate({});
      final result = failure.map((output) {
        isCalled = true;
        return output;
      });

      expect(result, same(failure));
      expect(isCalled, isFalse);
    });
  });
}
