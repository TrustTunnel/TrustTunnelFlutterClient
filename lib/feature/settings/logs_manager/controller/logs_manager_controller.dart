import 'dart:io';

import 'package:adg_share/adg_share.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/data/repository/export_logs_repository.dart';
import 'package:trusttunnel/feature/settings/logs_manager/controller/logs_manager_state.dart';
import 'package:trusttunnel/feature/settings/logs_manager/model/export_file_type.dart';

final class LogsManagerController extends BaseStateController<LogsManagerState> with SequentialControllerHandler {
  final ExportLogsRepository _repository;
  final ShareClient _shareClient;
  final Future<Directory?> Function() _downloadsDirectoryProvider;
  final Future<Directory> Function() _documentsDirectoryProvider;
  final Future<Directory> Function() _temporaryDirectoryProvider;

  LogsManagerController({
    required ExportLogsRepository repository,
    ShareClient shareClient = const AdgShare(),
    Future<Directory?> Function() downloadsDirectoryProvider = getDownloadsDirectory,
    Future<Directory> Function() documentsDirectoryProvider = getApplicationDocumentsDirectory,
    Future<Directory> Function() temporaryDirectoryProvider = getTemporaryDirectory,
    super.initialState = const LogsManagerState.initial(),
  }) : _repository = repository,
       _shareClient = shareClient,
       _downloadsDirectoryProvider = downloadsDirectoryProvider,
       _documentsDirectoryProvider = documentsDirectoryProvider,
       _temporaryDirectoryProvider = temporaryDirectoryProvider;

  void export({
    ValueChanged<String>? onArchiveReady,
    VoidCallback? onCanceled,
    VoidCallback? onError,
  }) => handle(
    () async {
      setState(
        const LogsManagerState.loading(),
      );

      final archive = await _repository.createArchive();
      final Directory? downloadDirectory;

      if (defaultTargetPlatform == TargetPlatform.macOS) {
        downloadDirectory = await _downloadsDirectoryProvider();
        final archivePath = await _repository.pickFilePath(
          fileName: archive.name,
          initialDirectory: downloadDirectory?.path,
          type: ExportFileType.custom,
          allowedExtensions: const ['zip'],
          data: archive.data,
        );

        if (archivePath == null) {
          setState(const LogsManagerState.idle());
          onCanceled?.call();

          return;
        }

        await _repository.saveRawFile(
          data: archive.data,
          path: archivePath,
          temporary: false,
        );

        setState(const LogsManagerState.idle());
        onArchiveReady?.call(archivePath);

        return;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        downloadDirectory = await _documentsDirectoryProvider();
      } else {
        downloadDirectory = await _downloadsDirectoryProvider();
      }

      if (downloadDirectory != null) {
        final downloadPath = '${downloadDirectory.path}${Platform.pathSeparator}${archive.name}';
        await _repository.saveRawFile(
          data: archive.data,
          path: downloadPath,
        );
      }

      final tempDirectory = await _temporaryDirectoryProvider();
      final tempPath = '${tempDirectory.path}${Platform.pathSeparator}${archive.name}';

      await _repository.saveRawFile(
        data: archive.data,
        path: tempPath,
      );

      setState(
        const LogsManagerState.idle(),
      );
      onArchiveReady?.call(tempPath);
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

  void _onError(Object? error, StackTrace? stackTrace) => setState(
    LogsManagerState.error(
      ExceptionUtils.toPresentationException(exception: error),
    ),
  );

  void _onCompleted() => setState(
    const LogsManagerState.idle(),
  );
}
