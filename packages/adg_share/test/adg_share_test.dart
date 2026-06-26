import 'dart:io';

import 'package:adg_share/adg_share.dart';
import 'package:adg_share/src/platform/model/share_payload.dart';
import 'package:adg_share/src/platform/share_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharePlatform initialPlatform;

  setUp(() {
    initialPlatform = SharePlatform.instance;
  });

  tearDown(() {
    SharePlatform.instance = initialPlatform;
  });

  group('AdgShare.share', () {
    test('uses SharePlatform.instance by default', () async {
      final platform = MockSharePlatform(
        response: <Object?, Object?>{'status': 'success'},
      );
      SharePlatform.instance = platform;

      final result = await const AdgShare().share(
        const ShareRequest(content: [ShareText('hello world')]),
      );

      expect(result, isA<ShareSuccess>());
      expect(platform.lastRequest?.content, hasLength(1));
    });

    test('returns ShareSuccess when platform reports success', () async {
      final platform = _RecordingSharePlatform(
        response: <Object?, Object?>{'status': 'success'},
      );
      final share = AdgShare(platform: platform);

      final result = await share.share(
        const ShareRequest(content: [ShareText('hello world')]),
      );

      expect(result, isA<ShareSuccess>());
      expect(platform.lastRequest?.content, hasLength(1));
      expect(platform.lastRequest?.content.single, isA<SharePayloadText>());
      expect(
        (platform.lastRequest?.content.single as SharePayloadText).text,
        'hello world',
      );
    });

    test('returns ShareDismissed when platform reports dismissed', () async {
      final platform = _RecordingSharePlatform(
        response: <Object?, Object?>{'status': 'dismissed'},
      );
      final share = AdgShare(platform: platform);

      final result = await share.share(
        const ShareRequest(content: [ShareText('dismiss me')]),
      );

      expect(result, isA<ShareDismissed>());
    });

    test('returns ShareFailure when platform omits status', () async {
      final platform = _RecordingSharePlatform();
      final share = AdgShare(platform: platform);

      final result = await share.share(
        const ShareRequest(content: [ShareText('hello world')]),
      );

      expect(result, isA<ShareFailure>());
      expect((result as ShareFailure).error, isA<ShareValidationException>());
    });

    test('returns ShareFailure when platform reports empty status', () async {
      final platform = _RecordingSharePlatform(
        response: <Object?, Object?>{'status': ''},
      );
      final share = AdgShare(platform: platform);

      final result = await share.share(
        const ShareRequest(content: [ShareText('hello world')]),
      );

      expect(result, isA<ShareFailure>());
      expect((result as ShareFailure).error, isA<ShareValidationException>());
    });

    test('returns ShareFailure with ShareValidationException for empty request', () async {
      final share = AdgShare(
        platform: _RecordingSharePlatform(),
      );

      final result = await share.share(const ShareRequest(content: []));

      expect(result, isA<ShareFailure>());
      expect((result as ShareFailure).error, isA<ShareValidationException>());
    });

    test('prepares file payload with resolved mime type and override name', () async {
      final platform = _RecordingSharePlatform(
        response: <Object?, Object?>{'status': 'success'},
      );
      final share = AdgShare(platform: platform);
      final tempDirectory = await Directory.systemTemp.createTemp('adg_share_test');
      final sourceFile = File(p.join(tempDirectory.path, 'report.txt'));
      await sourceFile.writeAsString('payload');

      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final result = await share.share(
        ShareRequest(
          content: [
            ShareFile(
              path: sourceFile.path,
              fileNameOverride: 'shared-report.txt',
            ),
          ],
        ),
      );

      expect(result, isA<ShareSuccess>());

      final content = platform.lastRequest?.content.single as SharePayloadFile;
      expect(content.mimeType, 'text/plain');
      expect(
        p.basename(content.path),
        endsWith('shared-report.txt'),
      );
    });

    test('returns ShareFailure when platform implementation is missing', () async {
      final share = AdgShare(platform: _ThrowingSharePlatform());

      final result = await share.share(
        const ShareRequest(content: [ShareText('hello world')]),
      );

      expect(result, isA<ShareFailure>());
      expect((result as ShareFailure).error, isA<UnimplementedError>());
    });
  });
}

final class MockSharePlatform with MockPlatformInterfaceMixin implements SharePlatform {
  final Map<Object?, Object?>? response;

  MockSharePlatform({this.response});

  SharePayload? lastRequest;

  @override
  Future<Map<Object?, Object?>?> share(SharePayload request) async {
    lastRequest = request;

    return response;
  }
}

final class _RecordingSharePlatform extends SharePlatform {
  final Map<Object?, Object?>? response;

  _RecordingSharePlatform({this.response});

  SharePayload? lastRequest;

  @override
  Future<Map<Object?, Object?>?> share(SharePayload request) async {
    lastRequest = request;

    return response;
  }
}

final class _ThrowingSharePlatform extends SharePlatform {
  @override
  Future<Map<Object?, Object?>?> share(SharePayload request) {
    throw UnimplementedError('Share platform is not implemented for this runtime.');
  }
}
