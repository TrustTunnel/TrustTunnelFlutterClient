import 'package:trusttunnel/common/platform/windows/protocol_registration.dart';
import 'package:win32_registry/win32_registry.dart' as registry;

/// A [ProtocolRegistrationStore] backed by the Windows registry.
final class Win32ProtocolRegistrationStore implements ProtocolRegistrationStore {
  static const String _classesKey = r'Software\Classes';
  static const String _commandKey = r'shell\open\command';
  static const String _iconKey = 'DefaultIcon';
  static const String _protocolValue = 'URL Protocol';

  const Win32ProtocolRegistrationStore();

  @override
  Future<String?> readCommand(RegistryRoot root, String scheme) async {
    final rootKey = _openRoot(root);
    try {
      final value = rootKey.getValue(
        '',
        path: '$_classesKey\\$scheme\\$_commandKey',
      );

      return value is registry.StringValue ? value.value : null;
    } finally {
      rootKey.close();
    }
  }

  @override
  Future<void> write(ProtocolRegistration registration) async {
    final rootKey = registry.Registry.currentUser;
    try {
      final schemeKey = rootKey.createKey('$_classesKey\\${registration.scheme}');
      try {
        schemeKey.createValue(registry.RegistryValue.string('', registration.description));
        schemeKey.createValue(const registry.RegistryValue.string(_protocolValue, ''));

        final iconKey = schemeKey.createKey(_iconKey);
        try {
          iconKey.createValue(registry.RegistryValue.string('', '"${registration.executable}",0'));
        } finally {
          iconKey.close();
        }

        final commandKey = schemeKey.createKey(_commandKey);
        try {
          commandKey.createValue(registry.RegistryValue.string('', registration.command));
        } finally {
          commandKey.close();
        }
      } finally {
        schemeKey.close();
      }
    } finally {
      rootKey.close();
    }
  }

  @override
  Future<void> delete(String scheme) async {
    final rootKey = registry.Registry.currentUser;
    try {
      rootKey.deleteKey('$_classesKey\\$scheme', recursive: true);
    } finally {
      rootKey.close();
    }
  }

  registry.RegistryKey _openRoot(RegistryRoot root) => switch (root) {
    RegistryRoot.currentUser => registry.Registry.currentUser,
    RegistryRoot.localMachine => registry.Registry.localMachine,
  };
}
