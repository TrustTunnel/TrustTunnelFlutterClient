import 'package:flutter_test/flutter_test.dart';
import 'package:trusttunnel/common/platform/windows/protocol_command_builder.dart';

void main() {
  const builder = ProtocolCommandBuilder();

  group('ProtocolCommandBuilder', () {
    test('quotes the executable and the URL placeholder', () {
      expect(
        builder.build(executable: r'C:\Program Files\TrustTunnel\TrustTunnel.exe'),
        r'"C:\Program Files\TrustTunnel\TrustTunnel.exe" "%1"',
      );
    });

    test('supports custom arguments', () {
      expect(
        builder.build(
          executable: r'C:\App\app.exe',
          arguments: const ['--open', '%1'],
        ),
        r'"C:\App\app.exe" "--open" "%1"',
      );
    });

    test('rejects an empty executable', () {
      expect(() => builder.build(executable: ''), throwsArgumentError);
    });

    test('rejects arguments without the URL placeholder', () {
      expect(
        () => builder.build(executable: r'C:\App\app.exe', arguments: const ['--open']),
        throwsArgumentError,
      );
    });
  });
}
