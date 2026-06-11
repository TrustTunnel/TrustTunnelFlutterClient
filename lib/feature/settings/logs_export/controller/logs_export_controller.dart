import 'dart:io';

import 'package:adg_share/adg_share.dart';
import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/data/repository/export_logs_repository.dart';
import 'package:trusttunnel/feature/settings/logs_export/controller/logs_export_state.dart';
import 'package:trusttunnel/feature/settings/logs_export/exception/logs_export_exception.dart';

typedef LogsExportCallback = void Function();

final class LogsExportController extends BaseStateController<LogsExportState> with SequentialControllerHandler {
  final ExportLogsRepository _repository;
  final ShareClient _shareClient;

  LogsExportController({
    required ExportLogsRepository repository,
    ShareClient shareClient = const AdgShare(),
    super.initialState = const LogsExportState.initial(),
  }) : _repository = repository,
       _shareClient = shareClient;

  void export({
    LogsExportCallback? onArchiveReady,
    LogsExportCallback? onCancelled,
  }) {
    handle(
      () async {
        if (state is LogsExportLoadingState) {
          return;
        }

        final previousArchive = state.archive;
        setState(const LogsExportState.loading());
        if (previousArchive != null) {
          await _deleteArchive(previousArchive);
        }

        final File archive;
        try {
          archive = await _repository.exportLogs();
        } on ExportLogsCancelledException {
          if (isDisposed) {
            return;
          }
          setState(const LogsExportState.idle());
          _callCallback(onCancelled);

          return;
        }
        if (isDisposed) {
          await _repository.deleteTemporaryArchive(archive);
          return;
        }

        setState(LogsExportState.idle(archive: archive));
        _callCallback(onArchiveReady);
      },
      errorHandler: _onExportError,
    );
  }

  void share({
    required String subject,
    required String chooserTitle,
    LogsExportCallback? onDismissed,
    LogsExportCallback? onUnavailable,
  }) {
    handle(
      () async {
        if (state is LogsExportLoadingState) {
          return;
        }

        final archive = state.archive;
        if (archive == null) {
          return;
        }

        setState(const LogsExportState.loading());

        try {
          final result = await _shareClient.share(
            ShareRequest(
              content: [
                ShareFile(
                  path: archive.path,
                  mimeType: 'application/zip',
                ),
              ],
              subject: subject,
              chooserTitle: chooserTitle,
            ),
          );

          if (isDisposed) {
            return;
          }

          switch (result) {
            case ShareSuccess():
              setState(const LogsExportState.idle());
            case ShareDismissed():
              setState(const LogsExportState.idle());
              _callCallback(onDismissed);
            case ShareUnavailable():
              setState(const LogsExportState.idle());
              _callCallback(onUnavailable);
            case ShareFailure(:final error):
              throw error;
          }
        } finally {
          await _deleteArchive(archive);
        }
      },
      errorHandler: _onShareError,
    );
  }

  Future<void> _onExportError(Object error, StackTrace stackTrace) async {
    setState(
      LogsExportState.error(
        LogsExportFailedPresentationException(
          ExceptionUtils.toPresentationException(exception: error),
        ),
      ),
    );
  }

  Future<void> _onShareError(Object error, StackTrace stackTrace) async {
    setState(
      LogsExportState.error(
        LogsShareFailedPresentationException(
          ExceptionUtils.toPresentationException(exception: error),
        ),
      ),
    );
  }

  void _callCallback(LogsExportCallback? callback) {
    if (isDisposed) {
      return;
    }
    try {
      callback?.call();
    } on Object catch (error, stackTrace) {
      onError(error, stackTrace);
    }
  }

  Future<void> _deleteArchive(File archive) async {
    try {
      await _repository.deleteTemporaryArchive(archive);
    } on Object catch (error, stackTrace) {
      onError(error, stackTrace);
    }
  }

  @override
  void dispose() {
    final archive = state.archive;
    if (archive != null && state is! LogsExportLoadingState) {
      _deleteArchive(archive).ignore();
    }

    super.dispose();
  }
}
