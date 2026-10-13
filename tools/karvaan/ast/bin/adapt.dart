import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class Controls extends RecursiveAstVisitor<void> {
  final edits=<({int start,int end,String value})>[];
  void call(String name,ArgumentList args) {
    final names=args.arguments.whereType<NamedExpression>().map((n)=>n.name.label.name).toSet();
    if(name.startsWith('DropdownButtonFormField')&&!names.contains('isExpanded'))edits.add((start:args.leftParenthesis.end,end:args.leftParenthesis.end,value:'isExpanded: true, '));
    if(name=='AppBar') {
      final height=args.arguments.whereType<NamedExpression>().where((arg)=>arg.name.label.name=='toolbarHeight').firstOrNull;
      if(height==null)edits.add((start:args.leftParenthesis.end,end:args.leftParenthesis.end,value:'toolbarHeight: 88*MediaQuery.textScalerOf(context).scale(1), '));
      else if(height.expression.toSource()=='88')edits.add((start:height.expression.offset,end:height.expression.end,value:'88*MediaQuery.textScalerOf(context).scale(1)'));
    }
    if(name=='AlertDialog'&&!names.contains('scrollable'))edits.add((start:args.leftParenthesis.end,end:args.leftParenthesis.end,value:'scrollable: true, '));
  }
  bool compact(AstNode node) {
    AstNode? parent=node.parent;
    while(parent!=null) {
      final name=parent is InstanceCreationExpression?parent.constructorName.toSource():parent is MethodInvocation?parent.methodName.name:'';
      if(['TextButton','FilledButton','OutlinedButton','ElevatedButton'].any((value)=>name.startsWith(value)))return true;
      parent=parent.parent;
    }
    return false;
  }
  void label(String name,int start,int end,AstNode node) {
    if(compact(node)&&(name=='BilingualText'||name=='BilingualOwnedText'))edits.add((start:start,end:end,value:name.replaceFirst('Text','Caption')));
  }
  void dataText(String name,int start,int end,ArgumentList arguments) {
    if(!{'BilingualText','BilingualCaption'}.contains(name)||arguments.arguments.isEmpty)return;
    final arg=arguments.arguments.first;
    if(arg is MethodInvocation && arg.methodName.name=='withValues'&&arg.target?.toSource()=='L10n.labelValuesa00644'&&arg.argumentList.arguments.first is ListLiteral) {
      final values=(arg.argumentList.arguments.first as ListLiteral).elements;
      if(values.length==1) {
        edits.removeWhere((edit)=>edit.start==start);
        edits.add((start:start,end:end,value:'Text'));
        edits.add((start:arg.offset,end:arg.end,value:'(${values.first.toSource()}).toString()'));
      }
    }
  }
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final name=node.constructorName.toSource();call(name,node.argumentList);
    label(name,node.constructorName.offset,node.constructorName.end,node);
    dataText(name,node.constructorName.offset,node.constructorName.end,node.argumentList);
    if(name=='InputDecoration' && !(node.parent is ArgumentList && node.parent!.parent is MethodInvocation && (node.parent!.parent as MethodInvocation).methodName.name=='bilingualDecoration')) {
      var source=node.toSource();if(source.startsWith('const '))source=source.substring(6);
      edits.add((start:node.offset,end:node.end,value:'bilingualDecoration(context,$source)'));
    }
    super.visitInstanceCreationExpression(node);
  }
  @override
  void visitMethodInvocation(MethodInvocation node) {
    call(node.methodName.name,node.argumentList);
    label(node.methodName.name,node.methodName.offset,node.methodName.end,node);
    dataText(node.methodName.name,node.methodName.offset,node.methodName.end,node.argumentList);
    if(node.methodName.name=='InputDecoration' && !(node.parent is ArgumentList && node.parent!.parent is MethodInvocation && (node.parent!.parent as MethodInvocation).methodName.name=='bilingualDecoration'))edits.add((start:node.offset,end:node.end,value:'bilingualDecoration(context,${node.toSource()})'));
    if(node.methodName.name=='withValues'&&node.argumentList.arguments.firstOrNull is ListLiteral) {
      final list=node.argumentList.arguments.first as ListLiteral;
      for(final value in list.elements.whereType<Expression>()) {
        final text=value.toSource();
        if(text.startsWith('TripStrings.')||text.startsWith('LifecycleStrings.')||text.startsWith('MasterStrings.')||text.startsWith('reportLabels[')||text=="f['label']"||text=='widget.kind.label'||text.startsWith('accountLabel(')||text.startsWith('eventLabel('))edits.add((start:value.offset,end:value.end,value:'ownedMessage($text)'));
        else if(value is BinaryExpression && value.operator.lexeme=='??' && value.rightOperand.toSource().startsWith('TripStrings.'))edits.add((start:value.rightOperand.offset,end:value.rightOperand.end,value:'ownedMessage(${value.rightOperand.toSource()})'));
      }
    }
    super.visitMethodInvocation(node);
  }
}

void main(List<String> args) {
  final root=Directory(args.single);
  var count=0;
  for(final file in Directory('${root.path}/app/lib').listSync(recursive:true).whereType<File>().where((file)=>file.path.endsWith('.dart'))) {
    var source=file.readAsStringSync();
    if(!source.contains("package:carrier_records/app/bilingual.dart"))continue;
    // Remove the prior broad injection's duplicate flag; the AST pass adds
    // flags only where the actual named-argument set lacks them.
    source=source.replaceAll('isExpanded: true, itemHeight: 80,','itemHeight: 80,');
    final visitor=Controls();
    parseString(content:source,path:file.path).unit.accept(visitor);
    for(final edit in visitor.edits..sort((a,b)=>b.start.compareTo(a.start)))source=source.replaceRange(edit.start,edit.end,edit.value);
    file.writeAsStringSync(source);
    count+=visitor.edits.length;
  }
  stdout.writeln('Applied $count syntax-aware compact/control edits.');
}
