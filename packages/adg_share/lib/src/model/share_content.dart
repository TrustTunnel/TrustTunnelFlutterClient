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
  const ShareText(this.text);

  final String text;
}

/// @template adg_share_file
/// File payload shared by path, with optional MIME and output name override.
/// @endtemplate
/// {@macro adg_share_file}
@immutable
final class ShareFile extends ShareContent {
  const ShareFile({
    required this.path,
    this.mimeType,
    this.fileNameOverride,
  });

  final String path;
  final String? mimeType;
  final String? fileNameOverride;
}

/// @template adg_share_uri
/// URI payload passed to the native share sheet.
/// @endtemplate
/// {@macro adg_share_uri}
@immutable
final class ShareUri extends ShareContent {
  const ShareUri(this.uri);

  final Uri uri;
}
