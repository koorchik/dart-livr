import 'dart:convert';

import 'package:livr/livr.dart';
import 'package:livr/util.dart';

// A custom rule: a builder gets the arguments from the schema and returns the
// rule, which returns a RuleResult
LivrRule strongPassword(List<Object?> args, RuleContext context) {
  final minLength = numberArg(args, 0, 'strong_password');

  return (value, allValues) {
    if (isNoValue(value)) return RuleResult.valid;
    if (value is! String) return RuleResult.error('FORMAT_ERROR');
    if (value.length < minLength || !value.contains(RegExp(r'\d'))) {
      return RuleResult.error('WEAK_PASSWORD');
    }
    return RuleResult.valid;
  };
}

// The type of the output, described by hand: an extension type over the
// output map, so reading a field is a map lookup and nothing is copied
extension type User(Map<String, Object?> _) {
  String get name => _['name'] as String;
  String get email => _['email'] as String;
  int? get age => _['age'] as int?;
  String get role => _['role'] as String;
  Address? get address => _['address'] as Address?;
}

extension type Address(Map<String, Object?> _) {
  String get city => _['city'] as String;
  int? get zip => _['zip'] as int?;
}

void main() {
  final validator = Validator(
    {
      'name': 'required',
      'email': ['required', 'email', 'to_lc'],
      'age': [
        'positiveInteger',
        {'minNumber': 18},
      ],
      'password': [
        'required',
        {'strong_password': 8},
      ],
      'address': {
        'nested_object': {'city': 'required', 'zip': 'positive_integer'},
      },
      'role': {'default': 'user'},
    },
    User.new,
    rules: {'strong_password': strongPassword},
  );

  final input = jsonDecode('''
    {
      "name": "John",
      "email": "John@Example.COM",
      "age": "25",
      "password": "secret123",
      "address": {"city": "Kyiv", "zip": "01001"},
      "is_admin": true
    }
  ''');

  switch (validator.validate(input)) {
    case ValidationSuccess(:final output):
      // john@example.com 25 Kyiv user
      print(
        '${output.email} ${output.age} ${output.address?.city} '
        '${output.role}',
      );
    case ValidationFailure(:final errors):
      print(errors);
  }

  // ValidationFailure({age: TOO_LOW, password: WEAK_PASSWORD,
  //   address: {zip: NOT_POSITIVE_INTEGER}})
  print(
    validator.validate({
      'name': 'John',
      'email': 'john@example.com',
      'age': 16,
      'password': 'secret',
      'address': {'city': 'Kyiv', 'zip': 'abc'},
    }),
  );
}
