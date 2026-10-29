import 'package:trusttunnel/common/platform/windows/protocol_registration.dart';

/// An in-memory [ProtocolRegistrationStore] for tests.
final class FakeProtocolRegistrationStore implements ProtocolRegistrationStore {
  /// Commands keyed by hive and scheme.
  final Map<RegistryRoot, Map<String, String>> commands = {};

  /// Registrations passed to [write].
  final List<ProtocolRegistration> writes = [];

  /// Schemes passed to [delete].
  final List<String> deletes = [];

  @override
  Future<String?> readCommand(RegistryRoot root, String scheme) async => commands[root]?[scheme];

  @override
  Future<void> write(ProtocolRegistration registration) async {
    writes.add(registration);
    commands.putIfAbsent(RegistryRoot.currentUser, () => {})[registration.scheme] = registration.command;
  }

  @override
  Future<void> delete(String scheme) async {
    deletes.add(scheme);
    commands[RegistryRoot.currentUser]?.remove(scheme);
  }
}
