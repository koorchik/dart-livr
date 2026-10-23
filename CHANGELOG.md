## 0.1.0

- First version: all rules of LIVR 2.0, aliases, custom rules and metarules, camelCase rule names, `autoTrim`.
- Typed by default: `Validator(schema, User.new)` returns `ValidationResult<User>`, with an extension type over the output map or a model class (`User.fromJson`); `Validator.untyped(schema)` returns the output as a map; `result.map(convert)` converts one result.
- Passes the LIVR test suite on the Dart VM, AOT and the web.
