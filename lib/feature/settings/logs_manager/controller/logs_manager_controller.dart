import 'dart:io';

import 'package:adg_share/adg_share.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/data/repository/export_logs_repository.dart';
import 'package:trusttunnel/feature/settings/logs_manager/controller/logs_manager_state.dart';

final class LogsManagerController extends BaseStateController<LogsManagerState> with SequentialControllerHandler {
  final ExportLogsRepository _repository;
  final ShareClient _shareClient;

  LogsManagerController({
    required ExportLogsRepository repository,
    ShareClient shareClient = const AdgShare(),
    super.initialState = const LogsManagerState.initial(),
  }) : _repository = repository,
       _shareClient = shareClient;

  void export({
    ValueChanged<String>? onArchiveReady,
    VoidCallback? onError,
  }) => handle(
    () async {
      setState(
        const LogsManagerState.loading(),
      );

      final archive = await _repository.createArchive();
      final downloadDir = await _getDownloadsDirectory();
      final downloadPath = '${downloadDir.path}${Platform.pathSeparator}${archive.name}';

      await _repository.saveRawFile(
        data: archive.data,
        path: downloadPath,
      );

      setState(
        const LogsManagerState.idle(),
      );
      onArchiveReady?.call(downloadPath);
    },
    errorHandler: (error, stackTrace) {
      onError?.call();
      _onError(error, stackTrace);
    },
    completionHandler: _onCompleted,
  );

  void share({
    required String subject,
    required String chooserTitle,
    required String filePath,
    VoidCallback? onDismissed,
    VoidCallback? onUnavailable,
  }) => handle(
    () async {
      setState(
        const LogsManagerState.loading(),
      );

      final result = await _shareClient.share(
        ShareRequest(
          content: [
            ShareFile(
              path: filePath,
              mimeType: 'application/zip',
            ),
          ],
          subject: subject,
          chooserTitle: chooserTitle,
        ),
      );

      switch (result) {
        case ShareSuccess():
          setState(const LogsManagerState.idle());
        case ShareDismissed():
          setState(const LogsManagerState.idle());
          onDismissed?.call();
        case ShareUnavailable():
          setState(const LogsManagerState.idle());
          onUnavailable?.call();
        case ShareFailure(:final error):
          throw error;
      }
    },
    errorHandler: (error, stackTrace) {
      onUnavailable?.call();
      _onError(error, stackTrace);
    },
    completionHandler: _onCompleted,
  );

  void deleteLogs({
    VoidCallback? onDeleted,
  }) => handle(
    () async {
      setState(
        const LogsManagerState.loading(),
      );

      await _repository.deleteLogs();

      setState(
        const LogsManagerState.idle(),
      );
      onDeleted?.call();
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  Future<Directory> _getDownloadsDirectory() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return getApplicationDocumentsDirectory();
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        final result = await Permission.manageExternalStorage.request();
        if (!result.isGranted) {
          return getTemporaryDirectory();
        }
        final directory = Directory('/storage/emulated/0/Download');

        if (!await directory.exists()) {
          final externalStorageDir = await getExternalStorageDirectory();

          return externalStorageDir ?? getTemporaryDirectory();
        }

        return directory;
      }
    }

    final result = await getDownloadsDirectory();

    return result ?? getTemporaryDirectory();
  }

  void _onError(Object? error, StackTrace? stackTrace) => setState(
    LogsManagerState.error(
      ExceptionUtils.toPresentationException(exception: error),
    ),
  );

  void _onCompleted() => setState(
    const LogsManagerState.idle(),
  );
}
