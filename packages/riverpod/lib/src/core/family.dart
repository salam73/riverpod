part of '../framework.dart';

/// A typedef representing the constructor of any classical provider.
@internal
typedef FunctionalProviderFactory< //
        ProviderT,
        CreatedT,
        RefT extends Ref<Object?>,
        ArgT>
    = ProviderT Function(
  Create<CreatedT, RefT> create, {
  required String? name,
  // ignore: prefer_void_to_null, explicitly using Null to cause a compilation error if non-null value is assigned
  required Null dependencies,
  // ignore: prefer_void_to_null, explicitly using Null to cause a compilation error if non-null value is assigned
  required Null allTransitiveDependencies,
  required DebugGetCreateSourceHash? debugGetCreateSourceHash,
  required bool isAutoDispose,
  required Family from,
  required ArgT argument,
});

/// A typedef representing the constructor of a [NotifierProvider].
@internal
typedef ClassProviderFactory< //
        NotifierT,
        ProviderT,
        CreatedT,
        RefT extends Ref<Object?>,
        ArgT>
    = ProviderT Function(
  NotifierT Function() create, {
  required String? name,
  required Iterable<ProviderOrFamily>? dependencies,
  required Iterable<ProviderOrFamily>? allTransitiveDependencies,
  required DebugGetCreateSourceHash? debugGetCreateSourceHash,
  required RunNotifierBuild<NotifierT, CreatedT, RefT>?
      runNotifierBuildOverride,
  required bool isAutoDispose,
  required Family from,
  required ArgT argument,
});

/// A [Create] equivalent used by [Family].
@internal
typedef FamilyCreate<CreatedT, RefT extends Ref<Object?>, ArgT> = CreatedT
    Function(RefT ref, ArgT arg);

/// A base class for all families
abstract class Family extends ProviderOrFamily implements _FamilyOverride {
  /// A base class for all families
  const Family({
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.isAutoDispose,
    required super.debugGetCreateSourceHash,
  });

  @override
  Family get from => this;
}

/// Setup how a family is overridden
@internal
typedef SetupFamilyOverride<Arg> = void Function(
  Arg argument,
  void Function({
    required ProviderBase<Object?> origin,
    required ProviderBase<Object?> override,
  }),
);

/// A base implementation for [Family], used by the various providers to
/// help them define a [Family].
///
/// This API is not meant for public consumption.
@internal
class FunctionalFamily< //
        RefT extends Ref<StateT>,
        StateT,
        ArgT,
        CreatedT,
        ProviderT extends FunctionalProvider<StateT, CreatedT, RefT>>
    extends Family {
  /// A base implementation for [Family], used by the various providers to
  /// help them define a [Family].
  ///
  /// This API is not meant for public consumption.
  const FunctionalFamily(
    this._createFn, {
    required FunctionalProviderFactory<ProviderT, CreatedT, RefT, ArgT>
        providerFactory,
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.isAutoDispose,
  }) : _providerFactory = providerFactory;

  final FunctionalProviderFactory<ProviderT, CreatedT, RefT, ArgT>
      _providerFactory;

  final CreatedT Function(RefT ref, ArgT arg) _createFn;

  /// {@template family.call}
  /// Create a provider from an external value.
  ///
  /// That external value should be immutable and preferably override `==`/`hashCode`.
  /// See the documentation of [Provider.family] for more information.
  /// {@endtemplate}
  ProviderT call(ArgT argument) {
    return _providerFactory(
      (ref) => _createFn(ref, argument),
      name: name,
      isAutoDispose: isAutoDispose,
      from: this,
      argument: argument,
      // TODO test all families set dependencies as null
      dependencies: null,
      allTransitiveDependencies: null,
      debugGetCreateSourceHash: debugGetCreateSourceHash,
    );
  }

  /// {@macro riverpod.override_with}
  Override overrideWith(
    CreatedT Function(RefT ref, ArgT arg) create,
  ) {
    return FamilyOverride(
      from: this,
      createElement: (container, provider) {
        provider as ProviderT;

        return provider
            .copyWithCreate((ref) => create(ref, provider.argument as ArgT))
            .createElement(container);
      },
    );
  }

  @override
  String toString() => name ?? describeIdentity(this);
}

/// A base implementation for [Family] specific to `Notifier`-based providers.
///
/// It offers a unique "create" function which does not take any argument.
///
/// This API is not meant for public consumption.
@internal
class ClassFamily< //
        NotifierT extends ClassBase< //
            StateT,
            CreatedT>,
        StateT,
        RefT extends Ref<StateT>,
        ArgT,
        CreatedT,
        ProviderT extends ClassProvider<NotifierT, StateT, CreatedT, RefT>>
    extends Family {
  /// A base implementation for [Family], used by the various providers to
  /// help them define a [Family].
  ///
  /// This API is not meant for public consumption.
  const ClassFamily(
    this._createFn, {
    required this.providerFactory,
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.isAutoDispose,
  });

// TODO docs
  @internal
  final ClassProviderFactory<NotifierT, ProviderT, CreatedT, RefT, ArgT>
      providerFactory;

  final NotifierT Function() _createFn;

  /// {@macro family.call}
  ProviderT call(ArgT argument) {
    return providerFactory(
      _createFn,
      name: name,
      isAutoDispose: isAutoDispose,
      from: this,
      argument: argument,
      dependencies: dependencies,
      allTransitiveDependencies: allTransitiveDependencies,
      debugGetCreateSourceHash: debugGetCreateSourceHash,
      runNotifierBuildOverride: null,
    );
  }

  /// {@macro riverpod.override_with}
  Override overrideWith(NotifierT Function() create) {
    return FamilyOverride(
      from: this,
      createElement: (container, provider) {
        provider as ProviderT;

        return provider.copyWithCreate(create).createElement(container);
      },
    );
  }

  /// {@macro riverpod.override_with}
  Override overrideWithBuild(
    RunNotifierBuild<NotifierT, CreatedT, RefT> build,
  ) {
    return FamilyOverride(
      from: this,
      createElement: (container, provider) {
        provider as ProviderT;

        return provider.copyWithBuild(build).createElement(container);
      },
    );
  }

  @override
  String toString() => name ?? describeIdentity(this);
}
