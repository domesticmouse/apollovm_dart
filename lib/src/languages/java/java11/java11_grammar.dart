import 'package:apollovm/apollovm.dart';
import 'package:petitparser/petitparser.dart';

import 'java11_grammar_lexer.dart';

/// Java11 grammar definition.
class Java11GrammarDefinition extends Java11GrammarLexer {
  static ASTType getTypeByName(String name) {
    switch (name) {
      case 'Object':
        return ASTTypeObject.instance;
      case 'int':
      case 'Integer':
        return ASTTypeInt.instance;
      case 'double':
      case 'Double':
        return ASTTypeDouble.instance;
      case 'String':
        return ASTTypeString.instance;
      case 'List':
        return ASTTypeArray(ASTTypeDynamic.instance);
      case 'var':
        return ASTTypeVar();
      default:
        return ASTType(name);
    }
  }

  @override
  Parser start() => ref0(compilationUnit).trim().end();

  Parser<ASTRoot> compilationUnit() =>
      (ref0(importDirective).star() & ref0(topLevelDefinition).star()).map((v) {
        var topDef = v[1];

        var classes = topDef as List;

        var root = ASTRoot();

        root.addAllClasses(classes.cast());

        root.resolveNode(null);

        return root;
      });

  Parser importDirective() =>
      (string('import') & literalString() & char(';').trim());

  Parser topLevelDefinition() => (classDeclaration());

  Parser<ASTClassNormal> classDeclaration() =>
      (string('class').trim() & identifier() & classCodeBlock()).map((v) {
        var name = v[1] as String;
        var block = v[2];
        var clazz = ASTClassNormal(name, ASTType<VMObject>(name), null);
        clazz.set(block);
        return clazz;
      });

  Parser<ASTBlock> classCodeBlock() => (char('{').trim() &
              (ref0(classFunctionDeclaration) |
                      ref0(classFieldDeclaration) |
                      ref0(classFieldDeclarationWithValue))
                  .star() &
              char('}').trim())
          .map((v) {
        var list = v[1] as List;
        var fields = list.whereType<ASTClassField>().toList();
        var functions = list.whereType<ASTFunctionDeclaration>().toList();

        var block = ASTClassNormal('?', ASTType<VMObject>('?'), null);

        block.addAllFields(fields);
        block.addAllFunctions(functions);

        return block;
      });

  Parser<ASTClassField> classFieldDeclaration() =>
      (modifiers().optional() & type() & identifier() & char(';').trim())
          .map((v) {
        var modifiers = (v[0] as ASTModifiers?) ?? ASTModifiers.modifiersNone;
        var type = v[1];
        var name = v[2];
        return ASTClassField(type, name, modifiers.isFinal);
      });

  Parser<ASTClassField> classFieldDeclarationWithValue() =>
      (modifiers().optional() &
              type() &
              identifier() &
              char('=').trim() &
              ref0(expression) &
              char(';').trim())
          .map((v) {
        var modifiers = (v[0] as ASTModifiers?) ?? ASTModifiers.modifiersNone;
        var type = v[1];
        var name = v[2];
        var expression = v[4];
        return ASTClassFieldWithInitialValue(
            type, name, expression, modifiers.isFinal);
      });

  Parser<ASTFunctionDeclaration> classFunctionDeclaration() =>
      (modifiers().optional() &
              type() &
              identifier() &
              parametersDeclaration() &
              codeBlock())
          .map((List v) {
        var modifiers = v[0];
        var returnType = v[1];
        var name = v[2];
        var parameters = v[3];
        var block = v[4];
        return ASTClassFunctionDeclaration(null, name, parameters, returnType,
            block: block, modifiers: modifiers);
      });

  Parser<ASTModifiers> modifiers() => (modifier().plus()).map((v) {
        v = v.map((e) => e.toString().trim()).toList();
        if (v.length > 1) {
          if (v.toSet().length != v.length) {
            throw SyntaxError('Duplicated function modifiers: $v');
          }
        }
        var isStatic = v.contains('static');
        var isFinal = v.contains('final');
        var isPrivate = v.contains('private');
        var isPublic = v.contains('private');
        return ASTModifiers(
            isStatic: isStatic,
            isFinal: isFinal,
            isPrivate: isPrivate,
            isPublic: isPublic);
      });

  Parser<String> modifier() => (string('public') |
          string('private') |
          string('final') |
          string('static'))
      .trim()
      .flatten();

  Parser<ASTBlock> codeBlock() =>
      (char('{').trim() & ref0(statement).star() & char('}').trim()).map((v) {
        var statements = (v[1] as List).cast<ASTStatement>().toList();
        return ASTBlock(null)..addAllStatements(statements);
      });

  Parser<ASTStatement> statement() => (branch() |
          statementReturn() |
          statementLoop() |
          statementVariableDeclaration() |
          statementExpression())
      .cast<ASTStatement>();

  Parser<ASTStatement> statementSimple() =>
      (statementVariableDeclaration() | statementExpression())
          .cast<ASTStatement>();

  Parser<ASTStatementForLoop> statementLoop() => (string('for').trim() &
              char('(').trim() &
              ref0(statementSimple) &
              ref0(expression) &
              char(';').trim() &
              ref0(expression) &
              char(')').trim() &
              codeBlock())
          .map((v) {
        var initExp = v[2];
        var condExp = v[3];
        var contExp = v[5];
        var block = v[7];
        return ASTStatementForLoop(initExp, condExp, contExp, block);
      });

  Parser<ASTStatementReturn> statementReturn() =>
      (string('return').trim() & expression().optional() & char(';').trim())
          .map((v) {
        var value = v[1];

        if (value == null) {
          return ASTStatementReturn();
        } else if (value is ASTExpression) {
          if (value is ASTExpressionVariableAccess) {
            if (value.variable.name == 'null') {
              return ASTStatementReturnNull();
            } else {
              return ASTStatementReturnVariable(value.variable);
            }
          } else if (value is ASTExpressionLiteral) {
            return ASTStatementReturnValue(value.value);
          } else {
            return ASTStatementReturnWithExpression(value);
          }
        }

        throw UnsupportedError("Can't handle return value: $value");
      });

  Parser<ASTStatementExpression> statementExpression() =>
      (expression() & char(';').trim()).map((v) {
        return ASTStatementExpression(v[0]);
      });

  Parser<ASTStatementVariableDeclaration> statementVariableDeclaration() =>
      (type() &
              identifier() &
              (char('=').trim() & ref0(expression)).optional() &
              char(';').trim())
          .map((v) {
        var valueOpt = v[2];
        var value = valueOpt != null ? valueOpt[1] : null;
        return ASTStatementVariableDeclaration(v[0], v[1], value);
      });

  Parser<ASTBranch> branch() => (ref0(branchIfElseIfsElseBlock) |
          ref0(branchIfElseBlock) |
          ref0(branchIfBlock))
      .cast<ASTBranch>();

  Parser<ASTBranchIfBlock> branchIfBlock() => (string('if').trim() &
              char('(').trim() &
              ref0(expression) &
              char(')').trim() &
              codeBlock())
          .map((v) {
        var condition = v[2];
        var block = v[4];
        return ASTBranchIfBlock(condition, block);
      });

  Parser<ASTBranchIfElseBlock> branchIfElseBlock() => (string('if').trim() &
              char('(').trim() &
              ref0(expression) &
              char(')').trim() &
              codeBlock() &
              string('else').trim() &
              codeBlock())
          .map((v) {
        var condition = v[2];
        var blockIf = v[4];
        var blockElse = v[6];
        return ASTBranchIfElseBlock(condition, blockIf, blockElse);
      });

  Parser<ASTBranchIfElseIfsElseBlock> branchIfElseIfsElseBlock() =>
      (string('if').trim() &
              char('(').trim() &
              ref0(expression) &
              char(')').trim() &
              codeBlock() &
              ref0(branchElseIfs).plus() &
              string('else').trim() &
              codeBlock())
          .map((v) {
        var condition = v[2];
        var blockIf = v[4];
        var blockElseIfs = v[5] as List;
        var blockElse = v[7];

        return ASTBranchIfElseIfsElseBlock(condition, blockIf,
            blockElseIfs.cast<ASTBranchIfBlock>().toList(), blockElse);
      });

  Parser<ASTBranchIfBlock> branchElseIfs() => (string('else').trim() &
              string('if').trim() &
              char('(').trim() &
              ref0(expression) &
              char(')').trim() &
              codeBlock())
          .map((v) {
        var condition = v[3];
        var blockIf = v[5];
        return ASTBranchIfBlock(condition, blockIf);
      });

  Parser<ASTExpression> expression() => (ref0(expressionNoOperation) &
              (expressionOperator() & ref0(expressionNoOperation)).star())
          .map((v) {
        var exp1 = v[0];

        var rest = v[1] as List;
        if (rest.isEmpty) {
          return exp1;
        }

        var extra = _expandListDeeply(rest);

        var all = <dynamic>[exp1, ...extra];

        while (all.length >= 3) {
          var e2 = all.removeLast();
          var op = all.removeLast();
          var e1 = all.removeLast();
          var exp = ASTExpressionOperation(e1, op, e2);
          all.add(exp);
        }
        assert(all.length == 1);

        return all[0] as ASTExpressionOperation;
      });

  Parser<ASTExpressionOperator> expressionOperator() => (char('+') |
              char('-') |
              char('*') |
              char('/') |
              string('==') |
              string('!=') |
              string('<=') |
              string('>=') |
              char('<') |
              char('>'))
          .trim()
          .map((v) {
        return getASTExpressionOperator(v);
      });

  Parser<ASTExpression> expressionNoOperation() => (expressionLiteral() |
          expressionVariableAssigment() |
          expressionFunctionInvocation() |
          expressionVariableEntryAccess() |
          expressionVariableAccess())
      .cast<ASTExpression>();

  Parser<ASTExpressionFunctionInvocation> expressionFunctionInvocation() =>
      ((identifier() & char('.')).optional() &
              identifier() &
              char('(').trim() &
              ref0(expressionSequence).optional() &
              char(')').trim())
          .map((v) {
        var objOpt = v[0] as List?;
        var obj = objOpt != null ? objOpt[0] as String : null;
        var name = v[1] as String;
        var args = v[3] as List<ASTExpression>?;
        args ??= <ASTExpression>[];

        if (obj != null && obj != 'this') {
          var variable = ASTScopeVariable(obj);
          return ASTExpressionObjectFunctionInvocation(variable, name, args);
        } else {
          return ASTExpressionLocalFunctionInvocation(name, args);
        }
      });

  Parser<List<ASTExpression>> expressionSequence() =>
      (ref0(expression) & (char(',').trim() & ref0(expression)).star())
          .map((v) {
        var list = _expandListDeeply(v);
        var expressions = list.whereType<ASTExpression>().toList();
        return expressions;
      });

  Parser<ASTExpressionVariableAccess> expressionVariableAccess() =>
      (variable()).map((v) {
        return ASTExpressionVariableAccess(v);
      });

  Parser<ASTExpressionLiteral> expressionLiteral() => (literal()).map((v) {
        return ASTExpressionLiteral(v);
      });

  Parser<ASTExpressionVariableEntryAccess> expressionVariableEntryAccess() =>
      (variable() & char('[') & ref0(expression) & char(']')).map((v) {
        var variable = v[0];
        var expression = v[2];
        return ASTExpressionVariableEntryAccess(variable, expression);
      });

  Parser<ASTExpressionVariableAssignment> expressionVariableAssigment() =>
      (variable() & assigmentOperator() & ref0(expression)).map((v) {
        return ASTExpressionVariableAssignment(v[0], v[1], v[2]);
      });

  Parser<ASTAssignmentOperator> assigmentOperator() =>
      (char('=') | string('+=')).trim().map((v) {
        return getASTAssignmentOperator(v);
      });

  Parser<ASTVariable> variable() =>
      (thisVariable() | scopeVariable()).cast<ASTVariable>();

  Parser<ASTThisVariable> thisVariable() => (token('this')).map((v) {
        return ASTThisVariable();
      });

  Parser<ASTScopeVariable> scopeVariable() => (identifier()).map((v) {
        return ASTScopeVariable(v);
      });

  Parser<ASTParametersDeclaration> parametersDeclaration() =>
      (emptyParametersDeclaration() | positionalParametersDeclaration())
          .cast<ASTParametersDeclaration>();

  Parser<ASTParametersDeclaration> emptyParametersDeclaration() =>
      (char('(') & char(')')).map((v) {
        return ASTParametersDeclaration(null, null, null);
      });

  Parser<ASTParametersDeclaration> positionalParametersDeclaration() =>
      (char('(') & parametersList() & char(')')).map((v) {
        return ASTParametersDeclaration(v[1], null, null);
      });

  Parser<List<ASTFunctionParameterDeclaration>> parametersList() =>
      (parameterDeclaration() & (char(',') & parameterDeclaration()).star())
          .map((v) {
        var params = _expandListDeeply(v);
        return params.whereType<ASTFunctionParameterDeclaration>().toList();
      });

  Parser<ASTFunctionParameterDeclaration> parameterDeclaration() =>
      (type() & identifier()).map((v) {
        return ASTFunctionParameterDeclaration(v[0], v[1], -1, false);
      });

  Parser<ASTType> type() => (arrayType() | simpleType()).cast<ASTType>();

  Parser<ASTType> simpleType() => identifier().map((v) {
        return getTypeByName(v);
      });

  Parser<ASTTypeArray> arrayType() =>
      (identifier() & string('[]').plus()).map((v) {
        var t = getTypeByName(v[0]);
        var dims = (v[1] as List).length;
        switch (dims) {
          case 1:
            return ASTTypeArray(t);
          case 2:
            return ASTTypeArray2D.fromElementType(t);
          case 3:
            return ASTTypeArray3D.fromElementType(t);
          default:
            throw UnsupportedSyntaxError(
                "Can't parse array with $dims dimensions: $dims");
        }
      });

  Parser<ASTValue> literal() =>
      (literalBool() | literalNum() | literalString()).cast<ASTValue>();

  Parser<ASTValueBool> literalBool() =>
      ((string('true') | string('false')).trim()).map((v) {
        return ASTValueBool(v == 'true');
      });

  Parser<ASTValueNum> literalNum() => (numberLexicalToken()).map((v) {
        return ASTValueNum.from(v);
      });

  Parser<ASTValueString> literalString() => (stringLexicalToken()).map((v) {
        return ASTValueString(v);
      });

  static List _expandListDeeply(List l) {
    if (l.isEmpty) return l;
    if (l.length == 1 && l[0] is! List) return l;

    return l.expand((e) => e is List ? _expandListDeeply(e) : [e]).toList();
  }
}
