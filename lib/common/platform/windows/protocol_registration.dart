/// A registry hive that can contain URL protocol registrations.
enum RegistryRoot {
  /// The per-user hive (`HKEY_CURRENT_USER`).
  currentUser,

  /// The machine-wide hive (`HKEY_LOCAL_MACHINE`).
  localMachine,
}

/// A URL protocol registration stored in the Windows registry.
final class ProtocolRegistration {
  /// The URL scheme, for example `tt`.
  final String scheme;

  /// The absolute path to the executable that handles the scheme.
  final String executable;

  /// The command line Windows runs when the scheme is invoked.
  final String command;

  /// The human-readable protocol description shown by Windows.
  final String description;

  /// Creates a protocol registration.
  const ProtocolRegistration({
    required this.scheme,
    required this.executable,
    required this.command,
    required this.description,
  });
}
