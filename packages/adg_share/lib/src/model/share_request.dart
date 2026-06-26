import 'dart:ui';

import 'package:meta/meta.dart';

import 'share_content.dart';
import 'share_target.dart';

/// @template adg_share_request
/// Immutable description of one native share operation.
/// @endtemplate
/// {@macro adg_share_request}
@immutable
final class ShareRequest {
  final List<ShareContent> content;

  final String? subject;
  final String? chooserTitle;
  final Rect? sharePositionOrigin;
  final List<ShareTarget> excludedTargets;
  const ShareRequest({
    required this.content,
    this.subject,
    this.chooserTitle,
    this.sharePositionOrigin,
    this.excludedTargets = const [],
  });
}
