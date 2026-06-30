import 'dart:convert';

import 'model/share_payload.dart';

final class ShareMethodChannelEncoder extends Converter<SharePayload, Map<String, Object?>> {
  const ShareMethodChannelEncoder();

  @override
  Map<String, Object?> convert(SharePayload input) => {
    'content': input.content.map(_encodeContent).toList(growable: false),
    'subject': input.subject,
    'chooserTitle': input.chooserTitle,
    'excludedTargets': input.excludedTargets,
    'sharePositionOrigin': _encodePositionOrigin(input.sharePositionOrigin),
  };

  Map<String, Object?> _encodeContent(SharePayloadItem item) => switch (item) {
    SharePayloadText(:final text) => {
      'type': 'text',
      'text': text,
    },
    SharePayloadUri(:final uri) => {
      'type': 'uri',
      'uri': uri,
    },
    SharePayloadFile(:final path, :final mimeType) => {
      'type': 'file',
      'path': path,
      'mimeType': mimeType,
    },
  };

  Map<String, Object?>? _encodePositionOrigin(SharePayloadPositionOrigin? origin) {
    if (origin == null) {
      return null;
    }

    return {
      'left': origin.left,
      'top': origin.top,
      'right': origin.right,
      'bottom': origin.bottom,
    };
  }
}
