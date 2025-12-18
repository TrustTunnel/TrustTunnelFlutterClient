import 'package:meta/meta.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/di/model/dependency_factory.dart';
import 'package:trusttunnel/di/model/repository_factory.dart';

/// Result of the application initialization phase.
///
/// `InitializationResult` groups together all artifacts produced during
/// startup that are required to run the application:
/// - resolved dependency graph ([dependenciesFactory]),
/// - repository layer ([repositoryFactory]),
/// - the initial VPN engine state ([initialVpnState]).
///
/// This object is typically created once during app startup and then passed
/// to the root of the application tree.
///
/// Instances are immutable and use value-based equality.
@immutable
class InitializationResult {
  /// Factory responsible for creating and wiring low-level dependencies.
  final DependencyFactory dependenciesFactory;

  /// Factory responsible for creating repositories used by the app.
  final RepositoryFactory repositoryFactory;

  /// VPN state observed at the end of initialization.
  final VpnState initialVpnState;

  /// Creates a new initialization result.
  const InitializationResult({
    required this.dependenciesFactory,
    required this.repositoryFactory,
    required this.initialVpnState,
  });

  @override
  int get hashCode => Object.hash(
    dependenciesFactory,
    repositoryFactory,
    initialVpnState,
  );

  @override
  String toString() =>
      'InitializationResult('
      'dependenciesFactory: $dependenciesFactory, '
      'repositoryFactory: $repositoryFactory, '
      'initialVpnState: $initialVpnState'
      ')';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is InitializationResult &&
        other.dependenciesFactory == dependenciesFactory &&
        other.repositoryFactory == repositoryFactory &&
        other.initialVpnState == initialVpnState;
  }

  /// Creates a copy of this result with the given fields replaced.
  ///
  /// Fields that are not provided retain their original values.
  InitializationResult copyWith({
    DependencyFactory? dependenciesFactory,
    RepositoryFactory? repositoryFactory,
    VpnState? initialVpnState,
  }) => InitializationResult(
    dependenciesFactory: dependenciesFactory ?? this.dependenciesFactory,
    repositoryFactory: repositoryFactory ?? this.repositoryFactory,
    initialVpnState: initialVpnState ?? this.initialVpnState,
  );
}
