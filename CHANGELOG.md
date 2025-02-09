## 0.0.30

- Using `async_extension` to optimize async calls.
  - Removed internal extensions with similar functionality.
- Migrated from `pedantic` to `lints`.
- Fixed missing await in `ASTExpressionVariableAssignment`.
- lints: ^1.0.1
- swiss_knife: ^3.0.8
- async_extension: ^1.0.6
- petitparser: ^4.2.0

## 0.0.29

- Improve `ApolloVMCore`:
  - Implementing portable `int` class for `dart` and `java11`:
    - `parse`, `parseInt`.
- Code generation:
  - Correctly normalize `int` and `Integer` for `dart` and `java11`.
- Improve `async` optimization.

## 0.0.28

- Implement static class accessor, to allow calls to static functions.
- Initial version of `ApolloVMCore`:
  - Implementing portable `String` class for `dart` and `java11`:
    - Mapping: `contains`, `toUpperCase`, `toLowerCase`, `valueOf`.
- Fixed class field code generation for `dart` and `java11`.
- `async` optimization:
  - Avoid instantiation of `Future`, using `FutureOrExtension` and
    `ListFutureOrExtension`:
    - `resolve`, `resolveMapped` and `resolveAllMapped`.
- Improved languages tests, to also executed regenerated code.

## 0.0.27

- Runner:
  - Strong types.
    - `var` types can be resolved.
    - `ASTTypedNode`: nodes can be typed,
      and resolution is performed and cached while running.
  - Optimize resolution of functions.
- Grammar:
  - Dart & Java:
    - `var` types to be resolved at runtime.

## 0.0.26

- Generator:
  - Dart & Java:
    - Improve String concatenation with variables. 

## 0.0.25

- Grammar:
  - Dart & Java:
    - Added `for` loop statement: `ASTStatementForLoop`.
- Adjust `README.md`.

## 0.0.24

- `ApolloVM`:
  - `parseLanguageFromFilePathExtension`
- `ApolloLanguageRunner`:
  - `tryExecuteFunction`
  - `tryExecuteClassFunction`
- Executable:
    - `apollovm`
- args: ^2.0.0
- pubspec: ^2.0.1
- path: ^1.8.0

## 0.0.23

- Improve tests, to tests definitions directory of XML files.

## 0.0.22

- `caseInsensitive` option for:
  - setField, getField, getFunctionWithName, getFunction,getClass 

## 0.0.21

- Better handling of function signature and how to pass positional and named parameters.

## 0.0.20

- Added `ASTClass.getFieldsMap`.
- `ASTEntryPointBlock.execute` with extra parameters `classInstanceObject` and `classInstanceFields`.
- Change signature of`dartRunner.executeFunction` and `javaRunner.executeClassMethod`.
  - Now they use named parameters for `positionalParameters` and `namedParameters`.

## 0.0.19

- Grammar:
  - Java & Dart:
    - Parse boolean literal.
- Improve API documentation.

## 0.0.18

- API Documentation.

## 0.0.17

- Fix call of function using `dynamic` type in parameter value.
- Code Generator:
  - Better formatting for classes and methods. 
- Grammar:
  - Dart:
    - Fix parsing of function with multiple parameters.
  - Java:
    - Class fields.
    - Fix parsing of function with multiple parameters.
    - Return statements ;

## 0.0.16

- Grammars:
  - Dart & Java11:
    - Fix parsing of multiple parameters.
- Runner:
  - Fix division with double and int.
- Code Generator:
  - Dart & Java11:
    - Fix variable assigment duplicated ';'.
  - Dart:
    - Improve string template regeneration, specially when
    parsed code comes from Java.
- Improved example.

## 0.0.15

- `ASTBlock`: added `functionsNames`.
- `ASTClass`: added `fields` and `fieldsNames`.
- `ApolloLanguageRunner`: added `getClass`.

## 0.0.14

- AST:
  - `ASTClassFunctionDeclaration`:
    To ensure that any class function is parsed from a class block
    and also ensure that is running from a class block.
- Generator:
  - Dart:
    - Fix non class function: due static modifier.
  - Java:
    - Will throw an exception if the generation of a function without
      a class is attempted.
- Runner:
  - Fix class object instance context.

## 0.0.13

- Grammar & Runner:
  - Dart & Java: 
    - Class fields.
    - Class object instance fields at runtime.
- Code Generator:
  - Dart & Java: 
    - Fix return statement with value/expression ;
  - Java:
    - Better/shorter code for String concatenation.

## 0.0.12

- Grammars & Code Generators & Runner:
  - Dart & Java11:
    - Better definition of static methods.
    - Class object instance.

## 0.0.11

- Renamed:
  - `ASTCodeBlock` -> `ASTBlock`. 
  - `ASTCodeRoot` -> `ASTRoot`.
  - `ASTCodeClass` -> `ASTClass`.
- Added support to `async` calls in `ASTNode` execution.
  - Any part of an `ASTNode` can have an `async` resolution.
    This allows the mapping of external functions that
    returns a `Future` or other languages that accepts
    `async` at any point.
- Better mapping of external functions:
  - Better Identification of number of parameters of mapped
    functions.
- Now an `ASTRoot` or an `ASTClass` are initialized:
  - Class/Root statements are executed once, and a context for
    each Class/Root is held during VM execution.

## 0.0.10

- Refactor:
  - Split `apollovm_ast.dart` into multiple `ast/apollovm_ast_*.dart` files.

## 0.0.9

- Code Generators:
  - Fix `else` branch indentation.

## 0.0.8

- Fix package description.
- Renamed Java8 to Java11:
  - Java 11 is closer to Dart 2 than Java 8.
- Grammars & Code Generators:
  - Dart & Java11:
    - Support `if`, `else if` and `else` branches. 

## 0.0.7

- Added type `ASTTypeBool` and value `ASTValueBool`.
- Added `ApolloVMNullPointerException`.
- Grammars & Code Generators:
  - Dart & Java8:
    - Support to expression comparison operators `==`, `!=`, `>`, `<`, `>=`, `<=`.
- Upgrade: petitparser: ^4.1.0

## 0.0.6

- Grammars:
  - Dart:
    - Added support for string templates:
      - including variable access: `$x`.
      - including expressions: `${ x * 2 }`.
      - Not implemented for multiline string yet.
  - Java8:
    - Support for string concatenation.
- Code Generators:
  - Java8:
    - Translate string templates to Java String concatenations.

## 0.0.5

- Grammars:
  - Dart:
    - Raw single line and raw multiline line strings.
    - Improved parser tests for literal String.

## 0.0.4

- Added type check:
  - `ASTType.isInstance`.
  - Function call now checks type signature and type inheritance.
- Grammars:
  - Dart:
    - Single line and multiline line strings with escaped chars.
  - Java8:
    - Single line strings with escaped chars.

## 0.0.3

- Removed `ASTCodeGenerator`, that is language specific now: `ApolloCodeGenerator`.
- Better external function mapping.
- Grammars:
  - Dart:
    - Expression operations: `+`, `-`, `*`, `/`, `~/`.
  - Java8:
    - Expression operations: `+`, `-`, `*`, `/`.
- Improved tests.

## 0.0.2

- Improved execution:
  - Now can call a class method or a function.
- Improved code generation:
  - Now supporting Java8 and Dart.
- Grammars:
  - Dart:
    - Basic class definition.
  - Java8:
    - Basic class definition.

## 0.0.1

- Basic Dart and Java8 support.
- Initial version, created by Stagehand
