import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'dart:async';
import 'package:macros/macros.dart';


part 'main.g.dart';

extension on ClassDeclaration {
  String get  notifierInterfaceName => '_\$${identifier.name}Impl';

  Future<MethodDeclaration?>  buildMethod(DeclarationPhaseIntrospector builder) async  {
    final methods = await builder.methodsOf(this);

    return methods.where((e) => e.identifier.name == 'build').firstOrNull;
  }
}


macro class Example
    implements ClassDeclarationsMacro,  ClassTypesMacro {
  const Example();

  @override
  FutureOr<void> buildDeclarationsForClass(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {


    builder.declareInType(
     DeclarationCode.fromParts([
        '  void method() {}',
     ]),
    );
  }

  @override
  FutureOr<void> buildTypesForClass(ClassDeclaration clazz, ClassTypeBuilder builder) async {
    builder.declareType('${clazz.identifier.name}Impl', DeclarationCode.fromString(
      'class ${clazz.identifier.name}Impl {}',
    ),);

    builder.appendInterfaces([
      RawTypeAnnotationCode.fromString('${clazz.identifier.name}Impl'),
    ]);
  }
}

/*
macro class Riverpod
    implements ClassDeclarationsMacro, ClassDefinitionMacro, ClassTypesMacro {
  const Riverpod({
    this.keepAlive = true,
    this.cb,
  });

  final bool keepAlive;
  final bool Function(String str)? cb;

  @override
  FutureOr<void> buildDeclarationsForClass(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    // if (!await _verifyValidNotifier(clazz, builder)) return;
  
    builder.declareInType(
     DeclarationCode.fromParts([
        '  ',
        clazz.identifier.name,
        '(Object ref) => _',
        clazz.identifier.name,
        '._(ref);',
     ]),
    );

//     final build = await clazz.buildMethod(builder);
//     build!;
//     if (!build.hasBody) {
//       builder.declareInType(DeclarationCode.fromString('''
//   augment int build() {
//     throw UnimplementedError();
//   }
// '''));
//     }
  }

  // @useResult
  // Future<bool> _verifyValidNotifier(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
  //   if (clazz.hasAbstract) {
  //     builder.report(
  //       Diagnostic(
  //         DiagnosticMessage('Annotated classes must not be abstract'),
  //         Severity.error,
  //       ),
  //     );

  //     return false;
  //   }

  //   if (clazz.superclass case final superclass?) {
  //     builder.report(
  //       Diagnostic(
  //         DiagnosticMessage(
  //           'Annotated classes must not specify `extends`',
  //           target: superclass.asDiagnosticTarget,
  //         ),
  //         Severity.error,
  //       ),
  //     );

  //     return false;
  //   }

  //   final build = await clazz.buildMethod(builder);
  //   if (build == null) {
  //     builder.report(
  //       Diagnostic(
  //         DiagnosticMessage(
  //           'Annotated classes must define a `build` method',
  //           target: clazz.asDiagnosticTarget,
  //         ),
  //         Severity.error,
  //       ),
  //     );
  //     return false;
  //   }

  //   return true;
  // }

  @override
  FutureOr<void> buildDefinitionForClass(ClassDeclaration clazz, TypeDefinitionBuilder builder) async {

  }
  
  @override
  FutureOr<void> buildTypesForClass(ClassDeclaration clazz, ClassTypeBuilder builder) async {
    final notifier = await builder.resolveIdentifier(Uri.parse('package:counter/main.dart'), 'Notifier');

    builder.declareType(clazz.notifierInterfaceName, DeclarationCode.fromString(
      'class ${clazz.notifierInterfaceName} {}',
    ),);

    builder.appendMixins([
      NamedTypeAnnotationCode(name: notifier),
    ]);

    builder.appendInterfaces([
      RawTypeAnnotationCode.fromString(clazz.notifierInterfaceName),
    ]);
  }
}
*/
// A Counter example implemented with riverpod

void main() {
  runApp(
    // Adding ProviderScope enables Riverpod for the entire project
    const ProviderScope(child: MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Home());
  }
}

/// Annotating a class by `@riverpod` defines a new shared state for your application,
/// accessible using the generated [counterProvider].
/// This class is both responsible for initializing the state (through the [build] method)
/// and exposing ways to modify it (cf [increment]).
@riverpod
class Counter extends _$Counter {
  /// Classes annotated by `@riverpod` **must** define a [build] function.
  /// This function is expected to return the initial state of your shared state.
  /// It is totally acceptable for this function to return a [Future] or [Stream] if you need to.
  /// You can also freely define parameters on this method.
  @override
  int build() => 0;

  void increment() => state++;
}

class Home extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter example')),
      body: Center(
        child: Text('${ref.watch(counterProvider)}'),
      ),
      floatingActionButton: FloatingActionButton(
        // The read method is a utility to read a provider without listening to it
        onPressed: () => ref.read(counterProvider.notifier).increment(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
