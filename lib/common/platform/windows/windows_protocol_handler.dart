import 'package:trusttunnel/common/platform/windows/protocol_command_builder.dart';
import 'package:trusttunnel/common/platform/windows/protocol_handler.dart';
import 'package:trusttunnel/common/platform/windows/protocol_registration.dart';
import 'package:trusttunnel/common/platform/windows/win32_protocol_registration_store.dart';

/// A [ProtocolHandler] for Windows registry-based URL protocol registrations.
///
/// The installer writes a machine-wide registration to `HKLM`, while
/// development and portable builds write a per-user registration to `HKCU`.
/// Because `HKCU` takes precedence over `HKLM`, a stale per-user key can shadow
/// a valid machine-wide registration. The handler reconciles both hives:
///
/// * when `HKLM` already points at `executable`, any per-user override is
///   removed so the installed application keeps working after an uninstall or
///   reinstall;
/// * otherwise the handler writes `HKCU`, which is how debug, profile, and
///   portable builds register themselves.
///
/// [unregister] only removes the per-user registration. The machine-wide
/// registration is owned and removed by the installer.
final class WindowsProtocolHandler implements ProtocolHandler {
  final ProtocolRegistrationStore _store;
  final ProtocolCommandBuilder _commandBuilder;
  final String _executable;
  final String _description;

  WindowsProtocolHandler({
    required this._store,
    required this._commandBuilder,
    required this._executable,
    required this._description,
  });

  @override
  Future<void> register(String scheme) async {
    final registration = _createRegistration(scheme);
    final machineCommand = await _store.readCommand(RegistryRoot.localMachine, scheme);

    if (_commandsMatch(machineCommand, registration.command)) {
      // HKLM is authoritative for this executable. Drop a per-user override so
      // it cannot shadow the machine-wide registration.
      if (await _store.readCommand(RegistryRoot.currentUser, scheme) != null) {
        await _store.delete(scheme);
      }

      return;
    }

    await _store.write(registration);
  }

  @override
  Future<void> unregister(String scheme) async {
    final registration = _createRegistration(scheme);
    final userCommand = await _store.readCommand(RegistryRoot.currentUser, scheme);

    if (!_commandsMatch(userCommand, registration.command)) {
      // Another executable owns the per-user registration; leave it untouched.
      return;
    }

    await _store.delete(scheme);
  }

  ProtocolRegistration _createRegistration(String scheme) {
    if (scheme.isEmpty) {
      throw ArgumentError.value(
        scheme,
        'scheme',
        'must not be empty',
      );
    }

    return ProtocolRegistration(
      scheme: scheme,
      executable: _executable,
      command: _commandBuilder.build(executable: _executable),
      description: _description,
    );
  }

  bool _commandsMatch(String? registered, String expected) =>
      registered != null && registered.trim().toLowerCase() == expected.trim().toLowerCase();
}
