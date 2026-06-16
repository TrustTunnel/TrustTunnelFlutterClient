import 'package:meta/meta.dart';

/// @template adg_share_content
/// Base type for a single payload item in a share request.
/// @endtemplate
@immutable
sealed class ShareContent {
  const ShareContent();
}

/// @template adg_share_text
/// Plain text payload for a native share sheet.
/// @endtemplate
/// {@macro adg_share_text}
@immutable
final class ShareText extends ShareContent {
  final String text;

  const ShareText(this.text);
}

/// @template adg_share_file
/// File payload shared by path, with optional MIME and output name override.
/// @endtemplate
/// {@macro adg_share_file}
@immutable
final class ShareFile extends ShareContent {
  final String path;

  final String? mimeType;
  final String? fileNameOverride;
  const ShareFile({
    required this.path,
    this.mimeType,
    this.fileNameOverride,
  });
}

/// @template adg_share_uri
/// URI payload passed to the native share sheet.
/// @endtemplate
/// {@macro adg_share_uri}
@immutable
final class ShareUri extends ShareContent {
  final Uri uri;

  const ShareUri(this.uri);
}
