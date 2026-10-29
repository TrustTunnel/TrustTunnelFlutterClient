import 'package:flutter_test/flutter_test.dart';
import 'package:trusttunnel/common/platform/windows/protocol_command_builder.dart';
import 'package:trusttunnel/common/platform/windows/protocol_registration.dart';
import 'package:trusttunnel/common/platform/windows/windows_protocol_handler.dart';

import 'fake_protocol_registration_store.dart';

void main() {
  const scheme = 'tt';
  const executable = r'C:\Program Files\TrustTunnel\TrustTunnel.exe';
  const command = r'"C:\Program Files\TrustTunnel\TrustTunnel.exe" "%1"';
  const otherCommand = r'"C:\Dev\TrustTunnel.exe" "%1"';

  late FakeProtocolRegistrationStore store;
  late WindowsProtocolHandler handler;

  setUp(() {
    store = FakeProtocolRegistrationStore();
    handler = WindowsProtocolHandler(
      store: store,
      commandBuilder: const ProtocolCommandBuilder(),
      executable: executable,
      description: 'URL:TrustTunnel Protocol',
    );
  });

  group('register', () {
    test('writes a per-user registration when HKLM is absent', () {
      handler.register(scheme);

      expect(store.writes, hasLength(1));
      expect(store.writes.single.scheme, scheme);
      expect(store.writes.single.command, command);
      expect(store.deletes, isEmpty);
    });

    test('writes a per-user override when HKLM points to another executable', () {
      store.commands[RegistryRoot.localMachine] = {scheme: otherCommand};

      handler.register(scheme);

      expect(store.writes, hasLength(1));
      expect(store.deletes, isEmpty);
    });

    test('removes a per-user override when HKLM points to this executable', () {
      store.commands[RegistryRoot.localMachine] = {scheme: command};
      store.commands[RegistryRoot.currentUser] = {scheme: otherCommand};

      handler.register(scheme);

      expect(store.writes, isEmpty);
      expect(store.deletes, [scheme]);
    });

    test('leaves HKCU untouched when HKLM matches and no override exists', () {
      store.commands[RegistryRoot.localMachine] = {scheme: command};

      handler.register(scheme);

      expect(store.writes, isEmpty);
      expect(store.deletes, isEmpty);
    });

    test('compares commands case-insensitively', () {
      store.commands[RegistryRoot.localMachine] = {scheme: command.toUpperCase()};

      handler.register(scheme);

      expect(store.writes, isEmpty);
    });
  });

  group('unregister', () {
    test('removes a per-user registration that points to this executable', () {
      store.commands[RegistryRoot.currentUser] = {scheme: command};

      handler.unregister(scheme);

      expect(store.deletes, [scheme]);
    });

    test('keeps a per-user registration that points to another executable', () {
      store.commands[RegistryRoot.currentUser] = {scheme: otherCommand};

      handler.unregister(scheme);

      expect(store.deletes, isEmpty);
    });

    test('does nothing when the per-user registration is absent', () {
      handler.unregister(scheme);

      expect(store.deletes, isEmpty);
    });
  });
}
