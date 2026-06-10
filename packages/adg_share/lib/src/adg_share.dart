import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'model/share_content.dart';
import 'model/share_exception.dart';
import 'model/share_request.dart';
import 'model/share_result.dart';
import 'platform/model/share_payload.dart';
import 'platform/share_platform.dart';
import 'support/io/share_file_preparation_stub.dart'
    if (dart.library.io) 'support/io/share_file_preparation_io.dart'
    as share_file_preparation;
import 'support/mime_type_resolver.dart';

/// @template adg_share_client
/// Entry point for native share operations.
/// @endtemplate
/// {@macro adg_share_client}
abstract interface class ShareClient {
  /// Opens the native share UI for the provided [request].
  Future<ShareResult> share(ShareRequest request);
}

/// {@macro adg_share_client}
@immutable
final class AdgShare implements ShareClient {
  const AdgShare({
    SharePlatform? platform,
    MimeTypeResolver? mimeTypeResolver,
  }) : _platform = platform ?? const _DelegatingSharePlatform(),
       _mimeTypeResolver = mimeTypeResolver ?? const MimeTypeResolver();

  final SharePlatform _platform;
  final MimeTypeResolver _mimeTypeResolver;

  @override
  Future<ShareResult> share(ShareRequest request) async {
    try {
      final payload = await _buildPayload(request);
      final response = await _platform.share(payload);
      return _mapResponse(response);
    } on ShareException catch (error) {
      return ShareFailure(error);
    } on PlatformException catch (error) {
      return ShareFailure(_mapPlatformException(error));
    } catch (error) {
      return ShareFailure(error);
    }
  }

  Future<SharePayload> _buildPayload(ShareRequest request) async {
    if (request.content.isEmpty) {
      throw const ShareValidationException('Share request content must not be empty.');
    }

    final content = <SharePayloadItem>[];

    for (final item in request.content) {
      switch (item) {
        case ShareText(:final text):
          final normalizedText = text.trim();
          if (normalizedText.isEmpty) {
            throw const ShareValidationException('Share text must not be empty.');
          }
          content.add(SharePayloadText(normalizedText));
        case ShareUri(:final uri):
          if (!uri.hasScheme || uri.scheme.isEmpty) {
            throw ShareValidationException('Share URI must contain a scheme: $uri');
          }
          content.add(SharePayloadUri(uri.toString()));
        case ShareFile():
          final normalizedPath = item.path.trim();
          if (normalizedPath.isEmpty) {
            throw const ShareValidationException('Share file path must not be empty.');
          }
          if (!await share_file_preparation.doesShareFileExist(normalizedPath)) {
            throw ShareFileNotFoundException(normalizedPath);
          }
          final mimeType = _mimeTypeResolver.resolve(
            filePath: normalizedPath,
            explicitMimeType: item.mimeType,
          );
          final preparedFile = await share_file_preparation.prepareShareFile(
            ShareFile(
              path: normalizedPath,
              mimeType: mimeType,
              fileNameOverride: item.fileNameOverride,
            ),
            mimeType: mimeType,
          );
          content.add(
            SharePayloadFile(
              path: preparedFile.path,
              mimeType: preparedFile.mimeType,
            ),
          );
      }
    }

    if (content.isEmpty) {
      throw const ShareValidationException('Share request content must not be empty.');
    }

    await share_file_preparation.cleanupStaleShareFiles();

    return SharePayload(
      content: content,
      subject: _normalizeOptionalText(request.subject),
      chooserTitle: _normalizeOptionalText(request.chooserTitle),
      excludedTargets: request.excludedTargets.map((target) => target.platformIdentifier).toList(growable: false),
      sharePositionOrigin: request.sharePositionOrigin == null
          ? null
          : SharePayloadPositionOrigin(
              left: request.sharePositionOrigin!.left,
              top: request.sharePositionOrigin!.top,
              right: request.sharePositionOrigin!.right,
              bottom: request.sharePositionOrigin!.bottom,
            ),
    );
  }

  ShareResult _mapResponse(Map<Object?, Object?>? response) {
    final status = response?['status'];
    if (status is! String || status.isEmpty) {
      return ShareFailure(
        ShareValidationException('Missing share result status.'),
      );
    }

    return switch (status) {
      'success' => const ShareSuccess(),
      'dismissed' => const ShareDismissed(),
      'unavailable' => const ShareUnavailable(),
      _ => ShareFailure(
        ShareValidationException('Unexpected share result status: $status'),
      ),
    };
  }

  Object _mapPlatformException(PlatformException error) => switch (error.code) {
    'permission_denied' => SharePermissionException(error.message ?? 'Platform denied share access.'),
    'file_not_found' => ShareFileNotFoundException(error.message ?? '<unknown>'),
    'unsupported' || 'share_unavailable' => UnimplementedError(
      error.message ?? 'Share platform is not implemented for this runtime.',
    ),
    'validation_error' => ShareValidationException(error.message ?? 'Invalid share request.'),
    _ => ShareValidationException(
      error.message ?? 'Unexpected platform error: ${error.code}',
    ),
  };

  String? _normalizeOptionalText(String? value) {
    final normalizedValue = value?.trim();
    return normalizedValue == null || normalizedValue.isEmpty ? null : normalizedValue;
  }
}

final class _DelegatingSharePlatform implements SharePlatform {
  const _DelegatingSharePlatform();

  @override
  Future<Map<Object?, Object?>?> share(SharePayload request) => SharePlatform.instance.share(request);
}
