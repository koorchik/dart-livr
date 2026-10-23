import 'dart:collection';

/// The field names of a compiled schema, shared by all its outputs.
final class Shape {
  Shape(this.names);

  final List<String> names;

  // Built on the first lookup in a large schema; a scan is faster for a few
  // fields and costs nothing to prepare
  Map<String, int>? _indexByName;
  static const int _maxNamesForScan = 8;

  int indexOf(Object? key) {
    final names = this.names;
    if (names.length <= _maxNamesForScan) {
      for (var i = 0; i < names.length; i++) {
        if (names[i] == key) return i;
      }
      return -1;
    }

    final indexByName = _indexByName ??= {
      for (var i = 0; i < names.length; i++) names[i]: i,
    };
    return indexByName[key] ?? -1;
  }
}

// Marks the fields that are not in an output
final class _Absent {
  const _Absent();
}

const Object absent = _Absent();

/// The output of a compiled schema: a mutable `Map` that keeps the values in
/// a list by the index of the field in the schema. Validation fills it by
/// index, without hashing, which is several times cheaper than building a
/// `LinkedHashMap`. Keys that are not in the schema, added later, are kept in
/// a separate map.
final class ObjectOutput extends MapBase<String, Object?> {
  /// [values] are by the index of [shape], [absent] for missing fields;
  /// [length] is the number of the other ones.
  ObjectOutput(this._shape, this._values, this._length);

  final Shape _shape;
  final List<Object?> _values;
  int _length;
  Map<String, Object?>? _otherValues;

  @override
  Object? operator [](Object? key) {
    final index = _shape.indexOf(key);
    if (index >= 0) {
      final value = _values[index];
      return identical(value, absent) ? null : value;
    }
    return _otherValues?[key];
  }

  @override
  void operator []=(String key, Object? value) {
    final index = _shape.indexOf(key);
    if (index >= 0) {
      if (identical(_values[index], absent)) _length++;
      _values[index] = value;
    } else {
      (_otherValues ??= <String, Object?>{})[key] = value;
    }
  }

  @override
  Object? remove(Object? key) {
    final index = _shape.indexOf(key);
    if (index < 0) return _otherValues?.remove(key);

    final value = _values[index];
    if (identical(value, absent)) return null;
    _values[index] = absent;
    _length--;
    return value;
  }

  @override
  bool containsKey(Object? key) {
    final index = _shape.indexOf(key);
    if (index >= 0) return !identical(_values[index], absent);
    return _otherValues?.containsKey(key) ?? false;
  }

  @override
  void clear() {
    _values.fillRange(0, _values.length, absent);
    _length = 0;
    _otherValues = null;
  }

  @override
  int get length => _length + (_otherValues?.length ?? 0);

  @override
  bool get isEmpty => length == 0;

  @override
  bool get isNotEmpty => length != 0;

  @override
  Iterable<String> get keys sync* {
    final names = _shape.names;
    final values = _values;
    for (var i = 0; i < names.length; i++) {
      if (!identical(values[i], absent)) yield names[i];
    }
    final otherValues = _otherValues;
    if (otherValues != null) yield* otherValues.keys;
  }

  @override
  void forEach(void Function(String key, Object? value) action) {
    final names = _shape.names;
    final values = _values;
    for (var i = 0; i < names.length; i++) {
      final value = values[i];
      if (!identical(value, absent)) action(names[i], value);
    }
    _otherValues?.forEach(action);
  }
}
