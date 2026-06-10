import 'package:meta/meta.dart';

/// @template adg_share_result
/// Base result returned after the plugin attempts to present share UI.
/// @endtemplate
@immutable
sealed class ShareResult {
  const ShareResult();
}

/// {@macro adg_share_result}
@immutable
final class ShareSuccess extends ShareResult {
  const ShareSuccess();
}

/// {@macro adg_share_result}
@immutable
final class ShareDismissed extends ShareResult {
  const ShareDismissed();
}

/// {@macro adg_share_result}
@immutable
final class ShareUnavailable extends ShareResult {
  const ShareUnavailable();
}

/// {@macro adg_share_result}
@immutable
final class ShareFailure extends ShareResult {
  const ShareFailure(this.error);

  final Object error;
}
