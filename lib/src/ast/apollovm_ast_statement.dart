import 'dart:async';

import 'package:apollovm/apollovm.dart';

import 'apollovm_ast_expression.dart';
import 'apollovm_ast_toplevel.dart';
import 'apollovm_ast_type.dart';
import 'apollovm_ast_value.dart';
import 'apollovm_ast_variable.dart';

/// An AST Statement.
abstract class ASTStatement implements ASTCodeRunner, ASTNode {
  @override
  VMContext defineRunContext(VMContext parentContext) {
    return parentContext;
  }
}

/// An AST Block of code (statements).
class ASTBlock extends ASTStatement {
  ASTBlock? parentBlock;

  ASTBlock(this.parentBlock);

  final Map<String, ASTFunctionSet> _functions = {};

  List<ASTFunctionSet> get functions => _functions.values.toList();

  List<String> get functionsNames => _functions.keys.toList();

  void addFunction(ASTFunctionDeclaration f) {
    var name = f.name;
    f.parentBlock = this;

    var set = _functions[name];
    if (set == null) {
      _functions[name] = ASTFunctionSetSingle(f);
    } else {
      var set2 = set.add(f);
      if (!identical(set, set2)) {
        _functions[name] = set2;
      }
    }
  }

  void addAllFunctions(Iterable<ASTFunctionDeclaration> fs) {
    for (var f in fs) {
      addFunction(f);
    }
  }

  bool containsFunctionWithName(
    String name,
  ) {
    var set = _functions[name];
    return set != null;
  }

  ASTFunctionDeclaration? getFunction(
    String fName,
    ASTFunctionSignature parametersSignature,
    VMContext context,
  ) {
    var set = _functions[fName];
    if (set != null) return set.get(parametersSignature, false);

    var fExternal =
        context.getMappedExternalFunction(fName, parametersSignature);
    return fExternal;
  }

  ASTType<T>? getFunctionReturnType<T>(String name,
          ASTFunctionSignature parametersTypes, VMContext context) =>
      getFunction(name, parametersTypes, context)?.returnType as ASTType<T>?;

  final List<ASTStatement> _statements = [];

  List<ASTStatement> get statements => _statements.toList();

  void set(ASTBlock? other) {
    if (other == null) return;

    _functions.clear();
    addAllFunctions(other._functions.values.expand((e) => e.functions));

    _statements.clear();
    addAllStatements(other._statements);
  }

  void addStatement(ASTStatement statement) {
    _statements.add(statement);
    if (statement is ASTBlock) {
      statement.parentBlock = this;
    }
  }

  void addAllStatements(Iterable<ASTStatement> statements) {
    for (var stm in statements) {
      addStatement(stm);
    }
  }

  @override
  VMContext defineRunContext(VMContext parentContext) {
    return parentContext;
  }

  @override
  FutureOr<ASTValue> run(
      VMContext parentContext, ASTRunStatus runStatus) async {
    var blockContext = defineRunContext(parentContext);

    FutureOr<ASTValue> returnValue = ASTValueVoid.INSTANCE;

    for (var stm in _statements) {
      var ret = await stm.run(blockContext, runStatus);

      if (runStatus.returned) {
        return (runStatus.returnedFutureValue ?? runStatus.returnedValue)!;
      }

      returnValue = ret;
    }

    return returnValue;
  }

  ASTClassField? getField(String name) =>
      parentBlock != null ? parentBlock!.getField(name) : null;
}

class ASTStatementValue extends ASTStatement {
  ASTValue value;

  ASTStatementValue(ASTBlock block, this.value) : super();

  @override
  FutureOr<ASTValue> run(VMContext parentContext, ASTRunStatus runStatus) {
    var context = defineRunContext(parentContext);
    return value.getValue(context) as FutureOr<ASTValue>;
  }
}

enum ASTAssignmentOperator { set, multiply, divide, sum, subtract }

ASTAssignmentOperator getASTAssignmentOperator(String op) {
  op = op.trim();

  switch (op) {
    case '=':
      return ASTAssignmentOperator.set;
    case '*=':
      return ASTAssignmentOperator.multiply;
    case '/=':
      return ASTAssignmentOperator.divide;
    case '+=':
      return ASTAssignmentOperator.sum;
    case '-=':
      return ASTAssignmentOperator.subtract;
    default:
      throw UnsupportedError('$op');
  }
}

String getASTAssignmentOperatorText(ASTAssignmentOperator op) {
  switch (op) {
    case ASTAssignmentOperator.set:
      return '=';
    case ASTAssignmentOperator.multiply:
      return '*=';
    case ASTAssignmentOperator.divide:
      return '/=';
    case ASTAssignmentOperator.sum:
      return '+=';
    case ASTAssignmentOperator.subtract:
      return '-=';
    default:
      throw UnsupportedError('$op');
  }
}

class ASTStatementExpression extends ASTStatement {
  ASTExpression expression;

  ASTStatementExpression(this.expression);

  @override
  FutureOr<ASTValue> run(VMContext parentContext, ASTRunStatus runStatus) {
    var context = defineRunContext(parentContext);
    return expression.run(context, runStatus);
  }
}

class ASTStatementReturn extends ASTStatement {
  @override
  FutureOr<ASTValue> run(VMContext parentContext, ASTRunStatus runStatus) {
    return runStatus.returnVoid();
  }
}

class ASTStatementReturnNull extends ASTStatementReturn {
  @override
  ASTValue run(VMContext parentContext, ASTRunStatus runStatus) {
    return runStatus.returnNull();
  }
}

class ASTStatementReturnValue extends ASTStatementReturn {
  ASTValue value;

  ASTStatementReturnValue(this.value);

  @override
  ASTValue run(VMContext parentContext, ASTRunStatus runStatus) {
    return runStatus.returnValue(value);
  }
}

class ASTStatementReturnVariable extends ASTStatementReturn {
  ASTVariable variable;

  ASTStatementReturnVariable(this.variable);

  @override
  FutureOr<ASTValue> run(VMContext parentContext, ASTRunStatus runStatus) {
    var value = variable.getValue(parentContext);
    return runStatus.returnFutureOrValue(value);
  }
}

class ASTStatementReturnWithExpression extends ASTStatementReturn {
  ASTExpression expression;

  ASTStatementReturnWithExpression(this.expression);

  @override
  FutureOr<ASTValue> run(VMContext parentContext, ASTRunStatus runStatus) {
    var value = expression.run(parentContext, runStatus);
    return runStatus.returnFutureOrValue(value);
  }
}

class ASTStatementVariableDeclaration<V> extends ASTStatement {
  ASTType<V> type;

  String name;

  ASTExpression? value;

  ASTStatementVariableDeclaration(this.type, this.name, this.value);

  @override
  FutureOr<ASTValue> run(
      VMContext parentContext, ASTRunStatus runStatus) async {
    var result = await value?.run(parentContext, runStatus);
    result ??= ASTValueNull.INSTANCE;
    parentContext.declareVariableWithValue(type, name, result);
    return ASTValueVoid.INSTANCE;
  }
}

abstract class ASTBranch extends ASTStatement {
  FutureOr<bool> evaluateCondition(VMContext parentContext,
      ASTRunStatus runStatus, ASTExpression condition) async {
    var evaluation = await condition.run(parentContext, runStatus);
    var evalValue = await evaluation.getValue(parentContext);

    if (evalValue is! bool) {
      throw StateError(
          'A branch condition should return a boolean: $evalValue');
    }

    return evalValue;
  }
}

class ASTBranchIfBlock extends ASTBranch {
  ASTExpression condition;
  ASTBlock block;

  ASTBranchIfBlock(this.condition, this.block);

  @override
  FutureOr<ASTValue> run(
      VMContext parentContext, ASTRunStatus runStatus) async {
    var evalValue =
        await evaluateCondition(parentContext, runStatus, condition);

    if (evalValue) {
      await block.run(parentContext, runStatus);
    }

    return ASTValueVoid.INSTANCE;
  }
}

class ASTBranchIfElseBlock extends ASTBranch {
  ASTExpression condition;
  ASTBlock blockIf;
  ASTBlock blockElse;

  ASTBranchIfElseBlock(this.condition, this.blockIf, this.blockElse);

  @override
  FutureOr<ASTValue> run(
      VMContext parentContext, ASTRunStatus runStatus) async {
    var evalValue =
        await evaluateCondition(parentContext, runStatus, condition);

    if (evalValue) {
      await blockIf.run(parentContext, runStatus);
    } else {
      await blockElse.run(parentContext, runStatus);
    }

    return ASTValueVoid.INSTANCE;
  }
}

class ASTBranchIfElseIfsElseBlock extends ASTBranch {
  ASTExpression condition;
  ASTBlock blockIf;
  List<ASTBranchIfBlock> blocksElseIf;
  ASTBlock blockElse;

  ASTBranchIfElseIfsElseBlock(
      this.condition, this.blockIf, this.blocksElseIf, this.blockElse);

  @override
  FutureOr<ASTValue> run(
      VMContext parentContext, ASTRunStatus runStatus) async {
    var evalValue =
        await evaluateCondition(parentContext, runStatus, condition);
    if (evalValue) {
      await blockIf.run(parentContext, runStatus);
      return ASTValueVoid.INSTANCE;
    } else {
      for (var branch in blocksElseIf) {
        evalValue =
            await evaluateCondition(parentContext, runStatus, branch.condition);

        if (evalValue) {
          await branch.block.run(parentContext, runStatus);
          return ASTValueVoid.INSTANCE;
        }
      }

      await blockElse.run(parentContext, runStatus);
      return ASTValueVoid.INSTANCE;
    }
  }
}
