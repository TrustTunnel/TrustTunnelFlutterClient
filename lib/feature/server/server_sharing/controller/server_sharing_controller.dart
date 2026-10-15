import 'dart:convert';

import 'package:adg_share/adg_share.dart';
import 'package:flutter/services.dart';
import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/common/utils/server_configuration_encoder.dart';
import 'package:trusttunnel/data/model/server_data.dart';
import 'package:trusttunnel/feature/server/server_sharing/controller/server_sharing_state.dart';

final class ServerSharingController extends BaseStateController<ServerSharingState> with SequentialControllerHandler {
  final Converter<ServerData, String> _encoder;
  final ShareClient _shareClient;

  ServerSharingController({
    this._encoder = const ServerConfigurationEncoder(),
    this._shareClient = const AdgShare(),
    super.initialState = const ServerSharingState.initial(),
  });

  void copyLink({
    required ServerData server,
    VoidCallback? onCopied,
    VoidCallback? onError,
  }) => handle(
    () async {
      setState(const ServerSharingState.loading());

      await Clipboard.setData(ClipboardData(text: _getLink(server)));

      if (!isDisposed) {
        onCopied?.call();
      }
    },
    errorHandler: (error, stackTrace) => _onError(error, onError),
    completionHandler: _onCompleted,
  );

  void share({
    required ServerData server,
    required Rect sharePositionOrigin,
    VoidCallback? onError,
  }) => handle(
    () async {
      setState(const ServerSharingState.loading());

      final result = await _shareClient.share(
        ShareRequest(
          content: [ShareText(_getLink(server))],
          sharePositionOrigin: sharePositionOrigin,
        ),
      );

      switch (result) {
        case ShareSuccess() || ShareDismissed():
          break;
        case ShareUnavailable():
          throw StateError('Native sharing is unavailable');
        case ShareFailure(:final error):
          throw error;
      }
    },
    errorHandler: (error, stackTrace) => _onError(error, onError),
    completionHandler: _onCompleted,
  );

  String _getLink(ServerData server) => 'tt://?${_encoder.convert(server)}';

  void _onError(Object error, VoidCallback? onError) {
    setState(ServerSharingState.error(ExceptionUtils.toPresentationException(exception: error)));

    onError?.call();
  }

  void _onCompleted() => setState(const ServerSharingState.idle());
}
