import 'dart:convert';
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

Map<String,dynamic>? message(Expression? expression) {
  if(expression is StringInterpolation) {
    final text=StringBuffer(),args=<String>[];
    for(final element in expression.elements) {
      if(element is InterpolationString)text.write(element.value);
      if(element is InterpolationExpression) {text.write('{${args.length}}');args.add(element.expression.toSource());}
    }
    return {'en':text.toString(),'args':args};
  }
  if(expression is StringLiteral && expression.stringValue!=null)return {'en':expression.stringValue,'args':<String>[]};
  return null;
}

Map<String,dynamic> presentation(Expression expression) {
  final literal=message(expression);
  if(literal!=null)return {'kind':'message',...literal};
  if(expression is ConditionalExpression)return {'kind':'conditional','condition':expression.condition.toSource(),'yes':presentation(expression.thenExpression),'no':presentation(expression.elseExpression)};
  if(expression is BinaryExpression && expression.operator.lexeme=='??')return {'kind':'fallback','value':expression.leftOperand.toSource(),'fallback':presentation(expression.rightOperand)};
  if(expression is SwitchExpression)return {'kind':'alternatives','options':expression.cases.map((arm)=>presentation(arm.expression)).toList()};
  return {'kind':'expression','source':expression.toSource()};
}

class Inventory extends RecursiveAstVisitor<void> {
  Inventory(this.file,this.source);
  final String file,source;
  final surfaces=<Map<String,dynamic>>[],known=<Map<String,dynamic>>[];
  void ownedBranches(Expression? expression,String symbol) {
    if(expression==null)return;
    void collect(Map<String,dynamic> node) {
      if(node['kind']=='message')known.add({...node,'symbol':symbol,'file':file,'line':line(expression.offset)});
      if(node['kind']=='conditional') {collect(node['yes']);collect(node['no']);}
      if(node['kind']=='fallback')collect(node['fallback']);
      if(node['kind']=='alternatives')for(final option in node['options'])collect(option);
    }
    collect(presentation(expression));
  }
  int line(int offset)=>'\n'.allMatches(source.substring(0,offset)).length+1;
  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Unresolved non-const constructor calls are MethodInvocation in parseString.
    if(node.target==null && node.methodName.name=='Text' && node.argumentList.arguments.isNotEmpty) {
      final expression=node.argumentList.arguments.first;
      surfaces.add({'file':file,'line':line(node.offset),'offset':node.offset,'end':node.end,'constructor_offset':node.methodName.offset,'arg_offset':expression.offset,'arg_end':expression.end,'source':expression.toSource(),'const':false,'message':message(expression),'presentation':presentation(expression),'named_arguments':node.argumentList.arguments.whereType<NamedExpression>().map((n)=>n.name.label.name).toList()});
    }
    if(node.target==null && {'FormatException','StateError'}.contains(node.methodName.name) && node.argumentList.arguments.isNotEmpty) {
      final text=message(node.argumentList.arguments.first);
      if(text!=null)known.add({...text,'file':file,'line':line(node.offset),'symbol':'error'});
    }
    super.visitMethodInvocation(node);
  }
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final name=node.constructorName.toSource();
    if(name=='Text' && node.argumentList.arguments.isNotEmpty) {
      final expression=node.argumentList.arguments.first;
      surfaces.add({'file':file,'line':line(node.offset),'offset':node.offset,'end':node.end,'constructor_offset':node.constructorName.offset,'arg_offset':expression.offset,'arg_end':expression.end,'source':expression.toSource(),'const':node.isConst,'message':message(expression),'presentation':presentation(expression),'named_arguments':node.argumentList.arguments.whereType<NamedExpression>().map((n)=>n.name.label.name).toList()});
    }
    if(name=='FormatException' && node.argumentList.arguments.isNotEmpty) {
      final text=message(node.argumentList.arguments.first);
      if(text!=null)known.add({...text,'file':file,'line':line(node.offset),'symbol':'error'});
    }
    super.visitInstanceCreationExpression(node);
  }
  @override
  void visitNamedExpression(NamedExpression node) {
    if({'labelText','hintText','errorText','helperText','tooltip','semanticsLabel'}.contains(node.name.label.name)) {
      surfaces.add({'file':file,'line':line(node.offset),'offset':node.offset,'end':node.end,'surface':node.name.label.name,'arg_offset':node.expression.offset,'arg_end':node.expression.end,'source':node.expression.toSource(),'message':message(node.expression),'presentation':presentation(node.expression)});
    }
    super.visitNamedExpression(node);
  }
  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final parent=node.thisOrAncestorOfType<ClassDeclaration>();
    final symbol=parent==null ? node.name.lexeme : '${parent.name.lexeme}.${node.name.lexeme}';
    if({'receiptStatus','error','message','status'}.contains(node.name.lexeme))ownedBranches(node.initializer,'safe.presentation');
    if(parent?.name.lexeme.endsWith('Strings')==true) {
      final text=message(node.initializer);
      if(text!=null)known.add({...text,'symbol':symbol,'file':file,'line':line(node.offset)});
    }
    if(node.initializer is SetOrMapLiteral && (node.name.lexeme.toLowerCase().contains('label') || node.name.lexeme.toLowerCase().contains('message') || node.name.lexeme=='outputTitles')) {
      for(final entry in (node.initializer as SetOrMapLiteral).elements.whereType<MapLiteralEntry>()) {
        final text=message(entry.value),key=message(entry.key);
        if(text!=null)known.add({...text,'symbol':'$symbol[${key?['en']}]','file':file,'line':line(entry.offset)});
      }
    }
    super.visitVariableDeclaration(node);
  }
  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if({'receiptStatus','error','message','status'}.contains(node.leftHandSide.toSource()))ownedBranches(node.rightHandSide,'safe.presentation');
    super.visitAssignmentExpression(node);
  }
  @override
  void visitReturnStatement(ReturnStatement node) {
    final function=node.thisOrAncestorOfType<FunctionDeclaration>()?.name.lexeme;
    if(node.thisOrAncestorOfType<MethodDeclaration>()?.name.lexeme=='totals'||function=='accountErrorMessage')ownedBranches(node.expression,'safe.presentation');
    super.visitReturnStatement(node);
  }
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if({'correctionError','tripError','accountErrorMessage'}.contains(node.name.lexeme) && node.functionExpression.body is ExpressionFunctionBody)ownedBranches((node.functionExpression.body as ExpressionFunctionBody).expression,'safe.presentation');
    super.visitFunctionDeclaration(node);
  }
  @override
  void visitEnumConstantDeclaration(EnumConstantDeclaration node) {
    final args=node.arguments?.argumentList.arguments;
    if(args!=null && args.length>=2) {
      final text=message(args[1]);
      if(text!=null)known.add({...text,'symbol':'enum.${node.name.lexeme}.label','file':file,'line':line(node.offset)});
    }
    super.visitEnumConstantDeclaration(node);
  }
}

void main(List<String> args) {
  final root=Directory(args.single).absolute;
  final surfaces=<Map<String,dynamic>>[],known=<Map<String,dynamic>>[];
  final files=Directory('${root.path}/app/lib').listSync(recursive:true).whereType<File>().where((f)=>f.path.endsWith('.dart'));
  for(final file in files) {
    final relative=file.path.substring(root.path.length+1).replaceAll('\\','/');
    if(relative.endsWith('/bilingual.dart')||relative.endsWith('/bilingual_message.dart')||relative.endsWith('/ui_catalogue.dart')||relative.endsWith('/bilingual_widgets.dart')||relative.endsWith('/owned_presentation.dart'))continue;
    final source=file.readAsStringSync();
    final visitor=Inventory(relative,source);
    parseString(content:source,path:file.path).unit.accept(visitor);
    known.addAll(visitor.known);
    if(!relative.endsWith('/output_pdf.dart')&&!relative.endsWith('/output_xlsx.dart'))surfaces.addAll(visitor.surfaces);
  }
  final result={'surfaces':surfaces,'known':known};
  File('${root.path}/tools/.local/karvaan-ast-inventory.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  stdout.writeln('AST inventory: ${surfaces.length} presentation nodes, ${known.length} owned labels/errors.');
}
