import 'dart:io';

import 'package:adg_share/adg_share.dart';
import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/error_utils.dart';
import 'package:trusttunnel/data/repository/export_logs_repository.dart';
import 'package:trusttunnel/feature/settings/logs_export/controller/logs_export_action.dart';
import 'package:trusttunnel/feature/settings/logs_export/controller/logs_export_state.dart';
import 'package:trusttunnel/feature/settings/logs_export/error/logs_export_error.dart';

typedef LogsExportActionListener = void Function(LogsExportAction action);

final class LogsExportController extends BaseStateController<LogsExportState> with SequentialControllerHandler {
  final ExportLogsRepository _repository;
  final ShareClient _shareClient = const AdgShare();
  final LogsExportActionListener? _actionListener;

  File? _archive;

  LogsExportController({
    required ExportLogsRepository repository,
    LogsExportActionListener? actionListener,
    super.initialState = const LogsExportState.initial(),
  }) : _repository = repository,
       _actionListener = actionListener;

  void export() {
    if (state.processing || isProcessing) {
      return;
    }

    handle(
      () async {
        final previousArchive = _archive;
        _archive = null;
        if (previousArchive != null) {
          await _deleteArchive(previousArchive);
        }
        setState(const LogsExportState.loading());

        final File archive;
        try {
          archive = await _repository.exportLogs();
        } on ExportLogsCancelledException {
          if (isDisposed) {
            return;
          }
          setState(const LogsExportState.idle());
          _callActionListener(const LogsExportAction.cancelled());

          return;
        }
        if (isDisposed) {
          await _repository.deleteTemporaryArchive(archive);
          return;
        }

        _archive = archive;
        setState(const LogsExportState.idle());
        _callActionListener(const LogsExportAction.archiveReady());
      },
      errorHandler: _onExportError,
    );
  }

  void share({
    required String subject,
    required String chooserTitle,
  }) {
    if (state.processing || isProcessing) {
      return;
    }
    final archive = _archive;
    if (archive == null) {
      return;
    }

    handle(
      () async {
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
              _callActionListener(const LogsExportAction.shareDismissed());
            case ShareUnavailable():
              setState(const LogsExportState.idle());
              _callActionListener(const LogsExportAction.shareUnavailable());
            case ShareFailure(:final error):
              throw error;
          }
        } finally {
          if (identical(_archive, archive)) {
            _archive = null;
          }
          await _deleteArchive(archive);
        }
      },
      errorHandler: _onShareError,
    );
  }

  Future<void> _onExportError(Object error, StackTrace stackTrace) async {
    setState(
      LogsExportState.error(
        LogsExportFailedPresentationError(
          ErrorUtils.toPresentationError(exception: error),
        ),
      ),
    );
  }

  Future<void> _onShareError(Object error, StackTrace stackTrace) async {
    setState(
      LogsExportState.error(
        LogsShareFailedPresentationError(
          ErrorUtils.toPresentationError(exception: error),
        ),
      ),
    );
  }

  void _callActionListener(LogsExportAction action) {
    if (isDisposed) {
      return;
    }
    try {
      _actionListener?.call(action);
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
    final archive = _archive;
    if (archive != null && !state.processing) {
      _archive = null;
      _deleteArchive(archive).ignore();
    }

    super.dispose();
  }
}
