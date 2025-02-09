import 'dart:async';

import 'package:async_extension/async_extension.dart';
import 'package:apollovm/apollovm.dart';
import 'package:collection/collection.dart'
    show MapEquality, equalsIgnoreAsciiCase;
import 'package:swiss_knife/swiss_knife.dart';

import 'apollovm_code_generator.dart';
import 'apollovm_code_storage.dart';
import 'apollovm_runner.dart';
import 'core/apollovm_core_base.dart';
import 'languages/dart/dart_generator.dart';
import 'languages/java/java11/java11_generator.dart';

/// The Apollo VM.
class ApolloVM implements VMTypeResolver {
  // ignore: non_constant_identifier_names
  static final String VERSION = '0.0.30';

  static int _idCount = 0;

  final int id = ++_idCount;

  /// Returns a parser for a [language].
  ApolloParser? getParser(String language) {
    switch (language) {
      case 'dart':
        return ApolloParserDart.instance;
      case 'java':
      case 'java11':
        return ApolloParserJava11.instance;
      default:
        return null;
    }
  }

  final Map<String, LanguageNamespaces> _languageNamespaces =
      <String, LanguageNamespaces>{};

  List<String> get loadedCodeLanguages => _languageNamespaces.keys.toList();

  /// Returns a [CodeNamespace] for [language] and [namespace].
  CodeNamespace? getNamespace(String language, String namespace) {
    var langNamespaces = getLanguageNamespaces(language);
    return langNamespaces.get(namespace);
  }

  /// Returns a [List] of [CodeNamespace] with name [namespace].
  List<CodeNamespace> getNamespaceWithName(String namespace) {
    return _languageNamespaces.values
        .map((langNs) => langNs.getIfLoaded(namespace))
        .whereType<CodeNamespace>()
        .toList();
  }

  /// Returns a [List] of [CodeNamespace] with name [namespace] and with class [className].
  List<CodeNamespace> getNamespaceWithNameAndClass(
      String namespace, String className,
      {bool caseInsensitive = false}) {
    return getNamespaceWithName(namespace)
        .where(
            (e) => e.containsClass(className, caseInsensitive: caseInsensitive))
        .toList();
  }

  /// Returns a [CodeNamespace] with class [className] for [language] (optional).
  List<CodeNamespace> getNamespaceWithClass(String className,
      {String? language, bool caseInsensitive = false}) {
    if (language != null) {
      var ns = _languageNamespaces[language];
      if (ns == null) return [];
      return ns.getNamespaceWithClass(className,
          caseInsensitive: caseInsensitive);
    } else {
      return _languageNamespaces.values.expand((ns) {
        var namespaces = ns.getNamespaceWithClass(className,
            caseInsensitive: caseInsensitive);
        return namespaces;
      }).toList();
    }
  }

  /// Returns a [LanguageNamespaces] for [language].
  LanguageNamespaces getLanguageNamespaces(String language) {
    return _languageNamespaces.putIfAbsent(
        language, () => LanguageNamespaces(language));
  }

  /// Loads [codeUnit], parsing the [CodeUnit.source] to the
  /// corresponding AST (Abstract Syntax Tree).
  Future<bool> loadCodeUnit(CodeUnit codeUnit) async {
    var language = codeUnit.language;
    var parser = getParser(language);

    if (parser == null) return false;

    var result = await parser.parse(codeUnit);

    if (!result.isOK) return false;

    var root = result.root!;

    var langNamespaces = getLanguageNamespaces(language);

    var codeNamespace = langNamespaces.get(root.namespace);

    codeUnit.root = root;

    codeNamespace.addCodeUnit(codeUnit);

    return true;
  }

  /// Creates a runner for the [language].
  ApolloLanguageRunner? createRunner(String language) {
    switch (language) {
      case 'dart':
        return ApolloRunnerDart(this);
      case 'java':
      case 'java11':
        return ApolloRunnerJava11(this);
      default:
        return null;
    }
  }

  /// Generate all the loaded code with [codeGenerator] implementation.
  void generateAllCode(ApolloCodeGenerator codeGenerator) {
    for (var languageNamespace in _languageNamespaces.values) {
      languageNamespace.generateAllCode(codeGenerator);
    }
  }

  /// Creates a [ApolloCodeGenerator] for the [language] and a [codeStorage].
  ApolloCodeGenerator? createCodeGenerator(
      String language, ApolloCodeStorage codeStorage) {
    switch (language) {
      case 'dart':
        return ApolloCodeGeneratorDart(codeStorage);
      case 'java':
      case 'java11':
        return ApolloCodeGeneratorJava11(codeStorage);
      default:
        return null;
    }
  }

  /// Generates all the VM loaded code in [language],
  /// returning a [ApolloCodeStorage].
  ApolloCodeStorage generateAllCodeIn(String language,
      {ApolloCodeStorage? codeStorage}) {
    codeStorage ??= ApolloCodeStorageMemory();
    var codeGenerator = createCodeGenerator(language, codeStorage);
    if (codeGenerator == null) {
      throw StateError(
          "Can't find an ApolloCodeGenerator for language: $language");
    }
    generateAllCode(codeGenerator);
    return codeStorage;
  }

  /// Returns the language associated with [fileOrExtension].
  static String parseLanguageFromFilePathExtension(String fileOrExtension) {
    String extension;
    if (fileOrExtension.contains(RegExp(r'\.\w+$'))) {
      extension = (getPathExtension(fileOrExtension) ?? fileOrExtension)
          .toLowerCase()
          .trim();
    } else {
      extension = fileOrExtension.toLowerCase().trim();
    }

    switch (extension) {
      case 'dart':
        return 'dart';
      case 'java':
        return 'java11';
      case 'js':
        return 'javascript';
      case 'py':
        return 'python';
      case 'rb':
        return 'ruby';
      case 'cs':
        return 'csharp';
      case 'kt':
        return 'kotlin';
      case 'cpp':
      case 'c++':
        return 'cpp';
      case 'swift':
        return 'swift';
      case 'pl':
      case 'perl':
        return 'perl';
      default:
        return 'dart';
    }
  }

  @override
  ASTType? resolveType(String typeName,
      {String? namespace, String? language, bool caseInsensitive = false}) {
    if (language != null && namespace != null) {
      var ns = getNamespace(language, namespace);
      if (ns == null) {
        return resolveCoreType(typeName,
            namespace: namespace,
            language: language,
            caseInsensitive: caseInsensitive);
      }
      var clazz = ns.getClass(typeName);
      return clazz?.type;
    }

    List<CodeNamespace> ns;
    if (namespace != null) {
      ns = getNamespaceWithNameAndClass(namespace, typeName,
          caseInsensitive: caseInsensitive);
    } else {
      ns = getNamespaceWithClass(typeName,
          language: language, caseInsensitive: caseInsensitive);
    }

    if (ns.isEmpty) {
      return resolveCoreType(typeName,
          namespace: namespace,
          language: language,
          caseInsensitive: caseInsensitive);
    }

    var clazz = ns.first.getClass(typeName, caseInsensitive: caseInsensitive);
    return clazz!.type;
  }

  ASTType? resolveCoreType(String typeName,
      {String? namespace, String? language, bool caseInsensitive = false}) {
    var clazz = ApolloVMCore.getClass(typeName);
    return clazz?.type;
  }

  @override
  String toString() {
    return 'ApolloVM{ id: $id, loadedCodeLanguages: $loadedCodeLanguages }';
  }
}

/// Language specific namespaces.
///
/// Each [CodeUnit] have a namespace, and they are stored separated by language.
class LanguageNamespaces {
  /// The language of the namespaces.
  final String language;

  LanguageNamespaces(this.language);

  final Map<String, CodeNamespace> _namespaces = <String, CodeNamespace>{};

  List<String> get namespaces => _namespaces.keys.toList();

  CodeNamespace get(String namespace) => _namespaces.putIfAbsent(
      namespace, () => CodeNamespace(language, namespace));

  CodeNamespace? getIfLoaded(String namespace) => _namespaces[namespace];

  /// Lookup for the first class [className] in [namespace] (optional).
  ASTClassNormal? getClass(String className,
      {String? namespace, bool caseInsensitive = false}) {
    if (namespace != null) {
      var ns = _namespaces[namespace];
      return ns?.getClass(className, caseInsensitive: caseInsensitive);
    } else {
      for (var ns in _namespaces.values) {
        var clazz = ns.getClass(className, caseInsensitive: caseInsensitive);
        if (clazz != null) {
          return clazz;
        }
      }
      return null;
    }
  }

  /// Returns a [List] of [CodeNamespace] with class [className].
  List<CodeNamespace> getNamespaceWithClass(String className,
      {bool caseInsensitive = false}) {
    return _namespaces.values
        .where((ns) =>
            ns.containsClass(className, caseInsensitive: caseInsensitive))
        .toList();
  }

  void generateAllCode(ApolloCodeGenerator codeGenerator) {
    for (var namespace in _namespaces.values) {
      namespace.generateAllCode(codeGenerator);
    }
  }

  /// returns a [List] of classes names.
  List<String> get classesNames =>
      _namespaces.values.expand((e) => e.classesNames).toList();

  /// returns a [List] of functions names.
  List<String> get functions =>
      _namespaces.values.expand((e) => e.functions).toList();
}

/// A namespace that can have multiple loaded [CodeUnit] instances.
class CodeNamespace {
  /// The language of the stored [CodeUnit].
  final String language;

  /// Name of the namespace.
  final String name;

  CodeNamespace(this.language, this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodeNamespace &&
          runtimeType == other.runtimeType &&
          language == other.language &&
          name == other.name;

  @override
  int get hashCode => language.hashCode ^ name.hashCode;

  final Set<CodeUnit> _codeUnits = {};

  /// Adds a loaded [codeUnit].
  void addCodeUnit(CodeUnit codeUnit) {
    _codeUnits.add(codeUnit);
  }

  /// Returns the 1st [CodeUnit] with a class with [className].
  CodeUnit? getCodeUnitWithClass(String className,
      {bool caseInsensitive = false}) {
    for (var cu in _codeUnits) {
      var clazz =
          cu.root!.getClass(className, caseInsensitive: caseInsensitive);
      if (clazz != null) return cu;
    }
    return null;
  }

  /// Returns a list of classes names.
  List<String> get classesNames =>
      _codeUnits.expand((e) => e.root!.classesNames).toList();

  /// Returns an [ASTClassNormal] for [className].
  ASTClassNormal? getClass(String className, {bool caseInsensitive = false}) {
    for (var cu in _codeUnits) {
      var clazz =
          cu.root!.getClass(className, caseInsensitive: caseInsensitive);
      if (clazz != null) return clazz;
    }
    return null;
  }

  /// Returns `true` if contains class with [className].
  bool containsClass(String className, {bool caseInsensitive = false}) {
    for (var cu in _codeUnits) {
      if (cu.root!.containsClass(className, caseInsensitive: caseInsensitive)) {
        return true;
      }
    }
    return false;
  }

  /// Returns a list of functions names.
  List<String> get functions =>
      _codeUnits.expand((e) => e.root!.functions).map((f) => f.name).toList();

  /// Returns the 1st [CodeUnit] with a function of name [fName].
  CodeUnit? getCodeUnitWithFunction(String fName,
      {bool caseInsensitive = false}) {
    for (var cu in _codeUnits) {
      if (cu.root!.containsFunctionWithName(fName,
          caseInsensitive: caseInsensitive)) return cu;
    }
    return null;
  }

  /// Returns a function with [fName] and [parametersSignature]
  /// (using [context] if needed).
  ASTFunctionDeclaration? getFunction(
      String fName, ASTFunctionSignature parametersSignature, VMContext context,
      {bool caseInsensitive = false}) {
    for (var cu in _codeUnits) {
      var f = cu.root!.getFunction(fName, parametersSignature, context,
          caseInsensitive: caseInsensitive);
      if (f != null) return f;
    }
    return null;
  }

  /// Generates all the code of this namespace using [codeGenerator].
  void generateAllCode(ApolloCodeGenerator codeGenerator) {
    var codeStorage = codeGenerator.codeStorage;
    for (var cu in _codeUnits) {
      var cuSource = cu.generateCode(codeGenerator);
      codeStorage.addSource(name, cu.id, cuSource.toString());
    }
  }
}

/// A Code Unit, with a [source] code in a specific [language].
class CodeUnit {
  /// Programming language of the [source] code.
  final String language;

  /// Source code.
  final String source;

  /// The ID of this Code Unit, usually a file path.
  final String id;

  CodeUnit(this.language, this.source, [this.id = '']);

  /// The [ASTRoot] corresponding to the parsed [source].
  ASTRoot? root;

  @override
  String toString() {
    return 'CodeUnit{language: $language, id: $id}';
  }

  /// Generates the code of this [ASTRoot] ([root]), using [codeGenerator].
  StringBuffer generateCode(ApolloCodeGenerator codeGenerator) {
    if (root == null) {
      throw StateError(
          'No ASTRoot! Ensure that this CodeUnit is loaded by ApolloVM!');
    }
    return codeGenerator.generateASTRoot(root!);
  }
}

/// A mapper for a function that is external to the [ApolloVM].
///
/// Used to map normal Dart functions to the [ApolloVM] instance.
/// This allows calls to Dart functions, like [print], from a source code
/// parsed and loaded by [ApolloVM].
class ApolloExternalFunctionMapper {
  final Map<String, ASTFunctionSet> _functions = {};

  /// Returns a mapped functions with [fName] and optional [parametersSignature].
  ASTExternalFunction<R>? getMappedFunction<R>(VMContext context, String fName,
      [ASTFunctionSignature? parametersSignature]) {
    var fSet = _functions[fName];
    if (fSet == null) return null;

    if (parametersSignature != null) {
      return fSet.get(parametersSignature, false) as ASTExternalFunction<R>;
    } else {
      return fSet.firstFunction as ASTExternalFunction<R>;
    }
  }

  /// Adds an external function ([fExternal]) to this mapping table.
  void addExternalFunction(ASTExternalFunction fExternal) {
    var fName = fExternal.name;
    var fSet = _functions[fName];

    if (fSet == null) {
      _functions[fName] = ASTFunctionSetSingle(fExternal);
    } else {
      _functions[fName] = fSet.add(fExternal);
    }
  }

  /// Maps an external function with 0 parameters.
  void mapExternalFunction0<T, R>(
      ASTType<R> fReturn, String fName, Function() f) {
    var fParameters = ASTParametersDeclaration(null, null, null);

    var fExternal = ASTExternalFunction(fName, fParameters, fReturn, f);

    addExternalFunction(fExternal);
  }

  /// Maps an external function with 1 parameter.
  void mapExternalFunction1<T, R>(ASTType<R> fReturn, String fName,
      ASTType<T> pType1, String pName1, Function(T p1) f) {
    var fParameters = ASTParametersDeclaration(
        [ASTFunctionParameterDeclaration(pType1, pName1, 0, false)],
        null,
        null);

    var fExternal = ASTExternalFunction(fName, fParameters, fReturn, f);

    addExternalFunction(fExternal);
  }

  /// Maps an external function with 2 parameters.
  void mapExternalFunction2<A, B, R>(
      ASTType<R> fReturn,
      String fName,
      ASTType<A> pType1,
      String pName1,
      ASTType<B> pType2,
      String pName2,
      Function(A p1, B p2) f) {
    var fParameters = ASTParametersDeclaration([
      ASTFunctionParameterDeclaration(pType1, pName1, 0, false),
      ASTFunctionParameterDeclaration(pType2, pName2, 1, false),
    ], null, null);

    var fExternal = ASTExternalFunction(fName, fParameters, fReturn, f);

    addExternalFunction(fExternal);
  }

  /// Maps an external function with 3 parameters.
  void mapExternalFunction3<A, B, C, R>(
      ASTType<R> fReturn,
      String fName,
      ASTType<A> pType1,
      String pName1,
      ASTType<B> pType2,
      String pName2,
      ASTType<B> pType3,
      String pName3,
      Function(A p1, B p2) f) {
    var fParameters = ASTParametersDeclaration([
      ASTFunctionParameterDeclaration(pType1, pName1, 0, false),
      ASTFunctionParameterDeclaration(pType2, pName2, 1, false),
      ASTFunctionParameterDeclaration(pType3, pName3, 1, false),
    ], null, null);

    var fExternal = ASTExternalFunction(fName, fParameters, fReturn, f);

    addExternalFunction(fExternal);
  }

  /// Maps an external function with 4 parameters.
  void mapExternalFunction4<A, B, C, D, R>(
      ASTType<R> fReturn,
      String fName,
      ASTType<A> pType1,
      String pName1,
      ASTType<B> pType2,
      String pName2,
      ASTType<B> pType3,
      String pName3,
      ASTType<B> pType4,
      String pName4,
      Function(A p1, B p2) f) {
    var fParameters = ASTParametersDeclaration([
      ASTFunctionParameterDeclaration(pType1, pName1, 0, false),
      ASTFunctionParameterDeclaration(pType2, pName2, 1, false),
      ASTFunctionParameterDeclaration(pType3, pName3, 1, false),
      ASTFunctionParameterDeclaration(pType4, pName4, 1, false),
    ], null, null);

    var fExternal = ASTExternalFunction(fName, fParameters, fReturn, f);

    addExternalFunction(fExternal);
  }
}

/// A runtime context, for classes, of the VM.
///
/// Implements the object instance reference of a running class.
class VMClassContext<T> extends VMContext {
  /// The class of this context.
  ASTClass<T> clazz;

  VMClassContext(this.clazz, {VMContext? parent, VMTypeResolver? typeResolver})
      : super(clazz, parent: parent, typeResolver: typeResolver);

  ASTValue<T>? _classInstance;

  /// An object instance of [clazz].
  @override
  ASTValue<T>? getClassInstance() => _classInstance;

  /// Defines the current object instance of this context.
  void setClassInstance(ASTValue<T> obj) {
    if (_classInstance != null && !identical(_classInstance, obj)) {
      throw StateError('ASTObjectInstance already set!');
    }
    _classInstance = obj;
  }
}

abstract class VMTypeResolver {
  /// Resolves an [ASTType] with [typeName].
  FutureOr<ASTType?> resolveType(String typeName,
      {String? namespace, String? language, bool caseInsensitive = false});
}

/// A runtime context of the VM.
///
/// Any code executed inside the VM has a context, that holds blocks
/// variables, functions and classes instances.
class VMContext {
  static VMContext? _current;

  /// Static setter for the current [VMContext].
  static VMContext? setCurrent(VMContext? context) {
    var prev = _current;
    _current = context;
    return prev;
  }

  /// Static access for the current [VMContext].
  static VMContext? getCurrent() => _current;

  /// The parent context.
  final VMContext? parent;

  VMContext? _root;

  /// The root context.
  VMContext? get root => _root ??= parent!.root;

  VMTypeResolver? _typeResolver;

  /// The type resolver. If not defined for this instance will get from [parent].
  ///
  /// The [root] should have a defined [typeResolver].
  VMTypeResolver get typeResolver => _typeResolver ??= parent!.typeResolver;

  /// The runtime block of this context.
  final ASTBlock block;

  VMContext(this.block, {this.parent, VMTypeResolver? typeResolver})
      : _typeResolver = typeResolver;

  final Map<String, ASTTypedVariable> _variables = {};

  /// Returns an [ASTVariable] of [name] in this context.
  ///
  /// - [allowClassFields] if true allows class fields.
  FutureOr<ASTVariable?> getVariable(String name, bool allowClassFields) {
    if (name == 'this') {
      var obj = getClassInstance();
      if (obj != null) {
        return ASTRuntimeVariable(obj.type, name, obj);
      }
    }

    var variable = _variables[name];
    if (variable != null) return variable;

    if (allowClassFields) {
      var obj = getClassInstance();
      if (obj != null) {
        if (obj is ASTClassInstance) {
          var fieldValue = obj.clazz
              .getInstanceFieldValue(this, ASTRunStatus.dummy, obj, name);
          return fieldValue.resolveMapped((v) {
            if (v != null) {
              return ASTRuntimeVariable(v.type, name, v);
            }
            return parent?.getVariable(name, allowClassFields);
          });
        }
      }
    }

    return parent?.getVariable(name, allowClassFields);
  }

  /// Sets an already declared variable of [name] with [value] in this context.
  ///
  /// - [allowClassFields] if true allows class fields.
  bool setVariable(String name, ASTValue value, bool allowField) {
    var variable = _variables[name];
    if (variable != null) {
      variable.setValue(this, value);
      return true;
    }

    var field = block.getField(name);

    if (field != null) {
      field.setValue(this, value);
      return true;
    }

    return false;
  }

  /// Declares a variable of [type] and [name] with an optional [value] in this context.
  bool declareVariableWithValue(ASTType type, String name, ASTValue? value) {
    value ??= ASTValueNull.instance;
    var variable = ASTRuntimeVariable(type, name, value);
    return declareVariable(variable);
  }

  /// Declares a variable of [type] and [name] without a initial value.
  bool declareVariable(ASTTypedVariable variable) {
    var name = variable.name;
    if (_variables.containsKey(name)) {
      throw StateError("Variable '$name' already declared: $variable");
    }
    _variables[name] = variable;
    return false;
  }

  /// Returns an [ASTVariable] of field [name].
  ASTVariable? getField(String name) {
    return block.getField(name);
  }

  /// The visible object class instance from this context.
  ///
  /// If [parent] is defined, will also look in the parent context.
  ASTValue? getClassInstance() => parent?.getClassInstance();

  /// Returns a function of [name] and [parametersSignature]
  ///
  /// If [parent] is defined, will also look in the parent context.
  ASTFunctionDeclaration? getFunction(
      String name, ASTFunctionSignature parametersSignature) {
    var f = block.getFunction(name, parametersSignature, this);
    if (f != null) return f;
    return parent?.getFunction(name, parametersSignature);
  }

  ApolloExternalFunctionMapper? externalFunctionMapper;

  /// Returns an [ASTExternalFunction] of [fName] and [parametersSignature].
  ///
  /// If [parent] is defined, will also look in the parent context.
  ASTExternalFunction<R>? getMappedExternalFunction<R>(String fName,
      [ASTFunctionSignature? parametersSignature]) {
    if (externalFunctionMapper != null) {
      var f = externalFunctionMapper!
          .getMappedFunction(this, fName, parametersSignature);
      if (f != null) return f as ASTExternalFunction<R>;
    }

    if (parent != null) {
      return parent!.getMappedExternalFunction(fName, parametersSignature);
    }

    return null;
  }
}

/// When a cast error happens while executing some code.
class ApolloVMCastException implements Exception {
  String? message;

  ApolloVMCastException([this.message]);

  @override
  String toString() {
    return 'ApolloVMCastException: $message';
  }
}

/// When a NPE happens while executing some code.
class ApolloVMNullPointerException implements Exception {
  String? message;

  ApolloVMNullPointerException([this.message]);

  @override
  String toString() {
    return 'ApolloVMNullPointerException: $message';
  }
}

/// An VM Object instance, with respective fields for class [type].
class VMObject extends ASTValue<dynamic> {
  static int _idCount = 0;

  final int id = ++_idCount;

  VMObject._(ASTType type) : super(type);

  static VMObject createInstance(VMContext context, ASTType type) {
    return VMObject._(type);
  }

  final Map<String, ASTRuntimeVariable> _fieldsValues =
      <String, ASTRuntimeVariable>{};

  /// Returns a [Map] with fields names and values.
  Map<String, ASTValue> getFieldsValues([VMContext? context]) {
    context ??= VMContext(ASTBlock(null));

    var fieldsValues = <String, ASTValue>{};

    for (var key in _fieldsValues.keys) {
      var value = getFieldValue(key, context);
      fieldsValues[key] = value ?? ASTValueNull.instance;
    }

    return fieldsValues;
  }

  /// Sets a field [value].
  ASTRuntimeVariable? setFieldValue(String fieldName, ASTValue value,
      [VMContext? context]) {
    var prev = _fieldsValues[fieldName];
    _fieldsValues[fieldName] = ASTRuntimeVariable(value.type, fieldName, value);
    return prev;
  }

  /// Returns a field value.
  ASTValue? getFieldValue(String fieldName, [VMContext? context]) {
    var prev = _fieldsValues[fieldName];
    if (prev == null) return null;
    context ??= VMContext(ASTBlock(null));
    var value = prev.getValue(context);
    return value;
  }

  /// Removes a field and resolves previous value.
  ASTValue? removeFieldValue(String fieldName, [VMContext? context]) {
    var prev = _fieldsValues.remove(fieldName);
    if (prev == null) return null;
    context ??= VMContext(ASTBlock(null));
    var value = prev.getValue(context);
    return value;
  }

  /// Removes a field.
  ASTRuntimeVariable? removeField(String fieldName, [VMContext? context]) {
    return _fieldsValues.remove(fieldName);
  }

  /// Set fields values from a [Map] [fieldsValues].
  void setFieldsValues(Map<String, ASTValue> fieldsValues,
      [VMContext? context]) {
    for (var entry in fieldsValues.entries) {
      setFieldValue(entry.key, entry.value, context);
    }
  }

  Iterable<String> get fieldsKeys => _fieldsValues.keys;

  Map<String, ASTType> get fieldsTypes =>
      _fieldsValues.map((key, value) => MapEntry(key, value.type));

  String? getFieldNameIgnoreCase(String fieldName) {
    if (_fieldsValues.containsKey(fieldName)) {
      return fieldName;
    }

    for (var k in _fieldsValues.keys) {
      if (equalsIgnoreAsciiCase(k, fieldName)) {
        return k;
      }
    }

    return null;
  }

  ASTRuntimeVariable? operator [](Object? field) => _fieldsValues[field];

  void operator []=(String field, ASTRuntimeVariable? value) {
    if (value == null) {
      _fieldsValues.remove(field);
    } else {
      _fieldsValues[field] = value;
    }
  }

  static final MapEquality _mapEquality = MapEquality();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VMObject &&
          runtimeType == other.runtimeType &&
          _mapEquality.equals(_fieldsValues, other._fieldsValues);

  @override
  int get hashCode => _mapEquality.hash(_fieldsValues);

  @override
  String toString() {
    return '${type.name}$fieldsTypes';
  }

  @override
  FutureOr getValue(VMContext context) {
    return _fieldsValues;
  }

  @override
  FutureOr getValueNoContext() {
    return _fieldsValues;
  }

  @override
  FutureOr<ASTValue> resolve(VMContext context) {
    return this;
  }
}
