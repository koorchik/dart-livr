// Benchmarks the scenarios of the LIVR benchmarks (https://js.livr-spec.org/why/performance):
// a simple form and a nested object, with a validator created once (static)
// and with a new validator for every validation (dynamic).
//
// Inputs are built once, in a pool of 1000 objects: building a map literal
// costs as much as validating it, and LIVR never changes its input. The
// numbers are of the library only, like in a service where the input comes
// from jsonDecode().
//
//   dart run benchmark/benchmark.dart
//   dart compile exe benchmark/benchmark.dart -o build/benchmark && build/benchmark
import 'package:livr/livr.dart';

final Map<String, Object?> simpleSchema = {
  'name': ['required', 'string'],
  'email': ['required', 'email'],
  'age': ['required', 'positive_integer'],
  'gender': {
    'one_of': ['male', 'female'],
  },
  'password': [
    'required',
    {'min_length': 8},
  ],
};

// The output of the simple form as a type: an extension type over the map
extension type SimpleForm(Map<String, Object?> _) {
  String get email => _['email'] as String;
  int get age => _['age'] as int;
}

Map<String, Object?> simpleInput(int i) => {
  'name': 'John Doe',
  'email': 'john.doe$i@example.com',
  'age': i % 2 == 0 ? 25 : '25',
  'gender': 'male',
  'password': 'secret-password',
  'extra': 'stripped',
};

// Every field is invalid: measures the errors path
Map<String, Object?> invalidSimpleInput(int i) => {
  'name': '',
  'email': 'john.doe$i@',
  'age': -1,
  'gender': 'unknown',
  'password': 'short',
};

final Map<String, Object?> nestedSchema = {
  'id': ['required', 'positive_integer'],
  'user': [
    'required',
    {
      'nested_object': {
        'name': ['required', 'string'],
        'address': [
          'required',
          {
            'nested_object': {
              'city': ['required', 'string'],
              'zip': [
                'required',
                {'like': r'^\d{5}$'},
              ],
            },
          },
        ],
      },
    },
  ],
  'tags': {
    'list_of': ['required', 'string'],
  },
};

Map<String, Object?> nestedInput(int i) => {
  'id': i + 1,
  'user': {
    'name': 'John Doe',
    'address': {'city': 'Kyiv', 'zip': '01001', 'extra': 'stripped'},
  },
  'tags': ['dart', 'livr', 'fast'],
};

void main() => runBenchmarks();

void runBenchmarks() {
  final simpleValidator = Validator.untyped(simpleSchema);
  final typedSimpleValidator = Validator(simpleSchema, SimpleForm.new);
  final nestedValidator = Validator.untyped(nestedSchema);
  final simpleInputs = List.generate(1000, simpleInput, growable: false);
  final nestedInputs = List.generate(1000, nestedInput, growable: false);
  final invalidInputs = List.generate(
    1000,
    invalidSimpleInput,
    growable: false,
  );

  final cases = <String, bool Function(int)>{
    'simple, static': (i) => simpleValidator.validate(simpleInputs[i]).isValid,
    'simple, typed': (i) {
      final result = typedSimpleValidator.validate(simpleInputs[i]);
      return result is ValidationSuccess<SimpleForm> && result.output.age == 25;
    },
    'simple, dynamic': (i) =>
        Validator.untyped(simpleSchema).validate(simpleInputs[i]).isValid,
    'nested, static': (i) => nestedValidator.validate(nestedInputs[i]).isValid,
    'nested, dynamic': (i) =>
        Validator.untyped(nestedSchema).validate(nestedInputs[i]).isValid,
    // Returns true for the expected result, like the other cases
    'invalid, static': (i) =>
        !simpleValidator.validate(invalidInputs[i]).isValid,
  };

  for (final MapEntry(key: name, value: run) in cases.entries) {
    if (!run(0)) throw StateError('$name: unexpected result');
    final ops = _opsPerSecond(run);
    final nsPerOp = (1e9 / ops).toStringAsFixed(0);
    print(
      '${name.padRight(16)} ${_format(ops).padLeft(12)} ops/sec'
      '  ${nsPerOp.padLeft(5)} ns/op',
    );
  }
}

double _opsPerSecond(bool Function(int) run) {
  // Warm-up, then the best of five runs of about 0.5 s each
  _measure(run, const Duration(milliseconds: 500));
  var best = 0.0;
  for (var i = 0; i < 5; i++) {
    final ops = _measure(run, const Duration(milliseconds: 500));
    if (ops > best) best = ops;
  }
  return best;
}

double _measure(bool Function(int) run, Duration duration) {
  final stopwatch = Stopwatch()..start();
  var iterations = 0;
  var valid = 0;
  while (stopwatch.elapsed < duration) {
    for (var i = 0; i < 1000; i++) {
      if (run(i)) valid++;
    }
    iterations += 1000;
  }
  if (valid != iterations) throw StateError('unexpected result');
  return iterations / stopwatch.elapsedMicroseconds * 1e6;
}

String _format(double ops) {
  final digits = ops.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
