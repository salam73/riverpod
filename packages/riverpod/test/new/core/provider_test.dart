import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

void main() {
  group('ProviderBase', () {
    // TODO assert all providers have an "internal" const constructor
    // TODO assert all non-internal constructors set allTransitiveDependencies

    test('allTransitiveDependencies', () {
      final a = Provider((ref) => 0);
      final b = Provider.family((ref, _) => 0, dependencies: [a]);
      final c = Provider((ref) => 0, dependencies: [b]);
      final d = Provider((ref) => 0, dependencies: [c]);

      expect(d.allTransitiveDependencies, containsAll(<Object>[a, b, c]));
    });
  });
}
