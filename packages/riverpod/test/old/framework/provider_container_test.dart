import 'package:mockito/mockito.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod/src/internals.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  group('ProviderContainer', () {
    group('when unmounting providers', () {
      test(
          'cleans up all the StateReaders of a provider in the entire ProviderContainer tree',
          () async {
        // Regression test for https://github.com/rrousselGit/riverpod/issues/1943
        final a = createContainer();
        // b/c voluntarily do not use the Provider, but a/d do. This is to test
        // that the disposal logic correctly cleans up the StateReaders
        // in all ProviderContainers associated with the provider, even if
        // some links between two ProviderContainers are not using the provider.
        final b = createContainer(parent: a);
        final c = createContainer(parent: b);
        final d = createContainer(parent: c);

        final provider = Provider.autoDispose((ref) => 3);

        final subscription = d.listen(
          provider,
          (previous, next) {},
          fireImmediately: true,
        );

        expect(a.hasStateReaderFor(provider), true);
        expect(b.hasStateReaderFor(provider), false);
        expect(c.hasStateReaderFor(provider), false);
        expect(d.hasStateReaderFor(provider), true);

        subscription.close();

        expect(a.hasStateReaderFor(provider), true);
        expect(b.hasStateReaderFor(provider), false);
        expect(c.hasStateReaderFor(provider), false);
        expect(d.hasStateReaderFor(provider), true);

        await a.pump();

        expect(a.hasStateReaderFor(provider), false);
        expect(b.hasStateReaderFor(provider), false);
        expect(c.hasStateReaderFor(provider), false);
        expect(d.hasStateReaderFor(provider), false);

        d.listen(
          provider,
          (previous, next) {},
          fireImmediately: true,
        );

        expect(a.hasStateReaderFor(provider), true);
        expect(b.hasStateReaderFor(provider), false);
        expect(c.hasStateReaderFor(provider), false);
        expect(d.hasStateReaderFor(provider), true);
      });
    });

    group('debugReassemble', () {
      test(
          'reload providers if the debugGetCreateSourceHash of a provider returns a different value',
          () {
        final noDebugGetCreateSourceHashBuild = OnBuildMock();
        final noDebugGetCreateSourceHash = Provider((ref) {
          noDebugGetCreateSourceHashBuild();
          return 0;
        });
        final constantHashBuild = OnBuildMock();
        final constantHash = Provider.internal(
          name: null,
          dependencies: null,
          allTransitiveDependencies: null,
          debugGetCreateSourceHash: () => 'hash',
          (ref) {
            constantHashBuild();
            return 0;
          },
        );
        var hashResult = '42';
        final changingHashBuild = OnBuildMock();
        final changingHash = Provider.internal(
          name: null,
          dependencies: null,
          allTransitiveDependencies: null,
          debugGetCreateSourceHash: () => hashResult,
          (ref) {
            changingHashBuild();
            return 0;
          },
        );
        final container = ProviderContainer();

        container.read(noDebugGetCreateSourceHash);
        container.read(constantHash);
        container.read(changingHash);

        clearInteractions(noDebugGetCreateSourceHashBuild);
        clearInteractions(constantHashBuild);
        clearInteractions(changingHashBuild);

        hashResult = 'new hash';
        container.debugReassemble();
        container.read(noDebugGetCreateSourceHash);
        container.read(constantHash);
        container.read(changingHash);

        verifyOnly(changingHashBuild, changingHashBuild());
        verifyNoMoreInteractions(constantHashBuild);
        verifyNoMoreInteractions(noDebugGetCreateSourceHashBuild);

        container.debugReassemble();
        container.read(noDebugGetCreateSourceHash);
        container.read(constantHash);
        container.read(changingHash);

        verifyNoMoreInteractions(changingHashBuild);
        verifyNoMoreInteractions(constantHashBuild);
        verifyNoMoreInteractions(noDebugGetCreateSourceHashBuild);
      });
    });

    test('invalidate triggers a rebuild on next frame', () async {
      final container = createContainer();
      final listener = Listener<int>();
      var result = 0;
      final provider = Provider((r) => result);

      container.listen(provider, listener.call);
      verifyZeroInteractions(listener);

      container.invalidate(provider);
      container.invalidate(provider);
      result = 1;

      verifyZeroInteractions(listener);

      await container.pump();

      verifyOnly(listener, listener(0, 1));
    });

    group('validate that properties respect `dependencies`', () {
      test('on reading an element, asserts that dependencies are respected',
          () {
        final dep = Provider((ref) => 0);
        final provider = Provider((ref) => ref.watch(dep));

        final root = createContainer();
        final container = createContainer(
          parent: root,
          overrides: [dep.overrideWithValue(42)],
        );

        expect(
          () => container.readProviderElement(provider),
          throwsA(isA<AssertionError>()),
        );
      });

      test(
          'on reading an element, asserts that transitive dependencies are also respected',
          () {
        final transitiveDep = Provider((ref) => 0);
        final dep = Provider((ref) => ref.watch(transitiveDep));
        final provider = Provider((ref) => ref.watch(dep));

        final root = createContainer();
        final container = createContainer(
          parent: root,
          overrides: [transitiveDep.overrideWithValue(42)],
        );

        expect(
          () => container.readProviderElement(provider),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('updateOverrides', () {
      test('is not allowed to remove overrides ', () {
        final provider = Provider((_) => 0);

        final container =
            createContainer(overrides: [provider.overrideWithValue(42)]);

        expect(container.read(provider), 42);

        expect(
          () => container.updateOverrides([]),
          throwsA(isAssertionError),
        );
      });
    });

    test(
        'flushes listened-to providers even if they have no external listeners',
        () async {
      final dep = StateProvider((ref) => 0);
      final provider = Provider((ref) => ref.watch(dep));
      final another = StateProvider<int>((ref) {
        ref.listen(provider, (prev, value) => ref.controller.state++);
        return 0;
      });
      final container = createContainer();

      expect(container.read(another), 0);

      container.read(dep.notifier).state = 42;

      expect(container.read(another), 1);
    });

    test(
        'flushes listened-to providers even if they have no external listeners (with ProviderListenable)',
        () async {
      final dep = StateProvider((ref) => 0);
      final provider = Provider((ref) => ref.watch(dep));
      final another = StateProvider<int>((ref) {
        ref.listen(provider, (prev, value) => ref.controller.state++);
        return 0;
      });
      final container = createContainer();

      expect(container.read(another), 0);

      container.read(dep.notifier).state = 42;

      expect(container.read(another), 1);
    });

    group('getAllProviderElements', () {
      test('list scoped providers that depends on nothing', () {
        final scopedProvider = Provider<int>((ref) => 0);
        final parent = createContainer();
        final child = createContainer(
          parent: parent,
          overrides: [scopedProvider],
        );

        child.read(scopedProvider);

        expect(
          child.getAllProviderElements().single,
          isA<ProviderElement<Object?>>()
              .having((e) => e.origin, 'origin', scopedProvider),
        );
      });

      test(
          'list scoped providers that depends on providers from another container',
          () {
        final dependency = Provider((ref) => 0);
        final scopedProvider = Provider<int>((ref) => ref.watch(dependency));
        final parent = createContainer();
        final child = createContainer(
          parent: parent,
          overrides: [scopedProvider],
        );

        child.read(scopedProvider);

        expect(
          child.getAllProviderElements().single,
          isA<ProviderElement<Object?>>()
              .having((e) => e.origin, 'origin', scopedProvider),
        );
      });

      test(
          'list only elements associated with the container (ignoring inherited and descendent elements)',
          () {
        final provider = Provider((ref) => 0);
        final provider2 = Provider((ref) => 0);
        final provider3 = Provider((ref) => 0);
        final root = createContainer();
        final mid = createContainer(parent: root, overrides: [provider2]);
        final leaf = createContainer(parent: mid, overrides: [provider3]);

        leaf.read(provider);
        leaf.read(provider2);
        leaf.read(provider3);

        expect(
          root.getAllProviderElements().single,
          isA<ProviderElement<Object?>>()
              .having((e) => e.provider, 'provider', provider),
        );
        expect(
          mid.getAllProviderElements().single,
          isA<ProviderElement<Object?>>()
              .having((e) => e.provider, 'provider', provider2),
        );
        expect(
          leaf.getAllProviderElements().single,
          isA<ProviderElement<Object?>>()
              .having((e) => e.provider, 'provider', provider3),
        );
      });

      test('list the currently mounted providers', () async {
        final container = ProviderContainer();
        final unrelated = Provider((_) => 42);
        final provider = Provider.autoDispose((ref) => 0);

        expect(container.read(unrelated), 42);
        var sub = container.listen(provider, (_, __) {});

        expect(
          container.getAllProviderElements(),
          unorderedMatches(<Matcher>[
            isA<ProviderElementBase<int>>(),
            isA<AutoDisposeProviderElementMixin<int>>(),
          ]),
        );

        sub.close();
        await container.pump();

        expect(
          container.getAllProviderElements(),
          [isA<ProviderElementBase<int>>()],
        );

        sub = container.listen(provider, (_, __) {});

        expect(
          container.getAllProviderElements(),
          unorderedMatches(<Matcher>[
            isA<ProviderElementBase<int>>(),
            isA<AutoDisposeProviderElementMixin<int>>(),
          ]),
        );
      });
    });

    group('getAllProviderElementsInOrder', () {
      test('list scoped providers that depends on nothing', () {
        final scopedProvider = Provider<int>((ref) => 0);
        final parent = createContainer();
        final child = createContainer(
          parent: parent,
          overrides: [scopedProvider],
        );

        child.read(scopedProvider);

        expect(
          child.getAllProviderElementsInOrder().single,
          isA<ProviderElement<Object?>>()
              .having((e) => e.origin, 'origin', scopedProvider),
        );
      });

      test(
          'list scoped providers that depends on providers from another container',
          () {
        final dependency = Provider((ref) => 0);
        final scopedProvider = Provider<int>((ref) => ref.watch(dependency));
        final parent = createContainer();
        final child = createContainer(
          parent: parent,
          overrides: [scopedProvider],
        );

        child.read(scopedProvider);

        expect(
          child.getAllProviderElementsInOrder().single,
          isA<ProviderElement<Object?>>()
              .having((e) => e.origin, 'origin', scopedProvider),
        );
      });
    });

    test(
        'does not re-initialize a provider if read by a child container after the provider was initialized',
        () {
      final root = createContainer();
      // the child must be created before the provider is initialized
      final child = createContainer(parent: root);

      var buildCount = 0;
      final provider = Provider((ref) {
        buildCount++;
        return 0;
      });

      expect(root.read(provider), 0);

      expect(buildCount, 1);

      expect(child.read(provider), 0);

      expect(buildCount, 1);
    });

    test('can downcast the listener value', () {
      final container = createContainer();
      final provider = StateProvider<int>((ref) => 0);
      final listener = Listener<void>();

      container.listen<void>(provider, listener.call);

      verifyZeroInteractions(listener);

      container.read(provider.notifier).state++;

      verifyOnly(listener, listener(any, any));
    });

    test(
      'can close a ProviderSubscription<Object?> multiple times with no effect',
      () {
        final container = createContainer();
        final provider =
            StateNotifierProvider<StateController<int>, int>((ref) {
          return StateController(0);
        });
        final listener = Listener<int>();

        final controller = container.read(provider.notifier);

        final sub = container.listen(provider, listener.call);

        sub.close();
        sub.close();

        controller.state++;

        verifyZeroInteractions(listener);
      },
    );

    test(
      'closing an already closed ProviderSubscription<Object?> does not remove subscriptions with the same listener',
      () {
        final container = createContainer();
        final provider =
            StateNotifierProvider<StateController<int>, int>((ref) {
          return StateController(0);
        });
        final listener = Listener<int>();

        final controller = container.read(provider.notifier);

        final sub = container.listen(provider, listener.call);
        container.listen(provider, listener.call);

        controller.state++;

        verify(listener(0, 1)).called(2);
        verifyNoMoreInteractions(listener);

        sub.close();
        sub.close();

        controller.state++;

        verifyOnly(listener, listener(1, 2));
      },
    );

    test('builds providers at most once per container', () {
      var result = 42;
      final container = createContainer();
      var callCount = 0;
      final provider = Provider((_) {
        callCount++;
        return result;
      });

      expect(callCount, 0);
      expect(container.read(provider), 42);
      expect(callCount, 1);
      expect(container.read(provider), 42);
      expect(callCount, 1);

      final container2 = createContainer();

      result = 21;
      expect(container2.read(provider), 21);
      expect(callCount, 2);
      expect(container2.read(provider), 21);
      expect(callCount, 2);
      expect(container.read(provider), 42);
      expect(callCount, 2);
    });
    test(
      'does not refresh providers if their dependencies changes but they have no active listeners',
      () async {
        final container = createContainer();

        var buildCount = 0;
        final dep = StateProvider((ref) => 0);
        final provider = Provider((ref) {
          buildCount++;
          return ref.watch(dep);
        });

        container.read(provider);

        expect(buildCount, 1);

        container.read(dep.notifier).state++;
        await container.pump();

        expect(buildCount, 1);
      },
    );
  });
}
