import 'package:meta/meta.dart';

/// @template adg_share_exception
/// Base exception for request validation and platform mapping errors.
/// @endtemplate
@immutable
sealed class ShareException implements Exception {
  final String message;

  const ShareException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// {@macro adg_share_exception}
@immutable
final class SharePermissionException extends ShareException {
  const SharePermissionException([super.message = 'The platform denied access required for sharing.']);
}

/// {@macro adg_share_exception}
@immutable
final class ShareFileNotFoundException extends ShareException {
  const ShareFileNotFoundException(String path) : super('Share file not found: $path');
}

/// {@macro adg_share_exception}
@immutable
final class ShareValidationException extends ShareException {
  const ShareValidationException(super.message);
}
