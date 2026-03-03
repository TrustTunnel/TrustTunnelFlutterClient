import 'package:trusttunnel/common/error/model/presentation_error.dart';

sealed class DeepLinkState {
  const DeepLinkState();

  const factory DeepLinkState.initial() = _DeepLinkInitialState;
  const factory DeepLinkState.idle() = _DeepLinkLoadingState;
  const factory DeepLinkState.loading() = _DeepLinkLoadingState;
  const factory DeepLinkState.exception({
    required PresentationError exception,
  }) = _DeepLinkErroredState;
}

class _DeepLinkLoadingState extends DeepLinkState {
  const _DeepLinkLoadingState();
}

class _DeepLinkIdleState extends DeepLinkState {
  const _DeepLinkIdleState();
}

class _DeepLinkErroredState extends DeepLinkState {
  final PresentationError exception;

  const _DeepLinkErroredState({
    required this.exception,
  });
}

class _DeepLinkInitialState extends _DeepLinkIdleState {
  const _DeepLinkInitialState();
}
