import 'package:meta/meta.dart';

@immutable
final class SharePayload {
  final List<SharePayloadItem> content;

  final String? subject;
  final String? chooserTitle;
  final List<String> excludedTargets;
  final SharePayloadPositionOrigin? sharePositionOrigin;
  const SharePayload({
    required this.content,
    this.subject,
    this.chooserTitle,
    this.excludedTargets = const [],
    this.sharePositionOrigin,
  });
}

@immutable
sealed class SharePayloadItem {
  const SharePayloadItem();
}

@immutable
final class SharePayloadText extends SharePayloadItem {
  final String text;

  const SharePayloadText(this.text);
}

@immutable
final class SharePayloadUri extends SharePayloadItem {
  final String uri;

  const SharePayloadUri(this.uri);
}

@immutable
final class SharePayloadFile extends SharePayloadItem {
  final String path;
  final String mimeType;

  const SharePayloadFile({
    required this.path,
    required this.mimeType,
  });
}

@immutable
final class SharePayloadPositionOrigin {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const SharePayloadPositionOrigin({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
}
