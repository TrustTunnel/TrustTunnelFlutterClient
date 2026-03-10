import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/data/model/server_data.dart';

sealed class DeepLinkState {
  final ServerData? parsedData;

  const DeepLinkState(this.parsedData);

  const factory DeepLinkState.initial() = _DeepLinkInitialState;
  const factory DeepLinkState.idle(ServerData? parsedData) = _DeepLinkLoadingState;
  const factory DeepLinkState.loading(ServerData? parsedData) = _DeepLinkLoadingState;
  const factory DeepLinkState.exception(
    ServerData? parsedData, {
    required PresentationError exception,
  }) = _DeepLinkErroredState;
}

class _DeepLinkLoadingState extends DeepLinkState {
  const _DeepLinkLoadingState(super.parsedData);
}

class _DeepLinkIdleState extends DeepLinkState {
  const _DeepLinkIdleState(super.parsedData);
}

class _DeepLinkErroredState extends DeepLinkState {
  final PresentationError exception;

  const _DeepLinkErroredState(
    super.parsedData, {
    required this.exception,
  });
}

class _DeepLinkInitialState extends _DeepLinkIdleState {
  const _DeepLinkInitialState() : super(null);
}
