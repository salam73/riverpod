// ignore_for_file: unused_local_variable

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'codegen.g.dart';

@riverpod
int other(OtherRef ref) {
  return 0;
}

/* SNIPPET START */
@riverpod
int example(ExampleRef ref) {
  ref.watch(otherProvider); // Good!
  ref.onDispose(() => ref.watch(otherProvider)); // Bad!

  final someListenable = ValueNotifier(0);
  someListenable.addListener(() {
    ref.watch(otherProvider); // Bad!
  });

  return 0;
}

@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  int build() {
    ref.watch(otherProvider); // Good!
    ref.onDispose(() => ref.watch(otherProvider)); // Bad!

    return 0;
  }

  void increment() {
    ref.watch(otherProvider); // Bad!
  }
}
