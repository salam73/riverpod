// ignore_for_file: avoid_print, avoid_unused_constructor_parameters

import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

class Todo {
  const Todo(this.id);
  Todo.fromJson(Object obj) : id = 0;

  final int id;
}

class Http {
  Future<List<Object>> get(String str) async => [str];
  Future<List<Object>> post(String str) async => [str];
}

final http = Http();

/* SNIPPET START */
class MyNotifier extends AsyncNotifier<List<Todo>> {
  @override
  FutureOr<List<Todo>> build() async {
    final json = await http.get('api/todos');
    return [...json.map(Todo.fromJson)];
  }
}

final myNotifierProvider =
    AsyncNotifierProvider.autoDispose<MyNotifier, int>(MyNotifier.new);
