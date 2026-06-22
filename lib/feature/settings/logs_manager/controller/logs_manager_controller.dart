import 'package:adg_share/adg_share.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
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
    VoidCallback? onArchiveReady,
    VoidCallback? onError,
  }) => handle(
    () async {
      setState(
        LogsManagerState.loading(archive: state.archive),
      );

      final archive = await _repository.createArchive();

      setState(
        LogsManagerState.idle(archive: archive),
      );
      onArchiveReady?.call();
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
    VoidCallback? onDismissed,
    VoidCallback? onUnavailable,
  }) => handle(
    () async {
      final archive = state.archive;
      if (archive == null) {
        return;
      }

      setState(
        LogsManagerState.loading(archive: archive),
      );

      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/${archive.name}';

      await _repository.saveRawFile(
        data: archive.data,
        path: tempPath,
      );

      final result = await _shareClient.share(
        ShareRequest(
          content: [
            ShareFile(
              path: tempPath,
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
        LogsManagerState.loading(archive: state.archive),
      );

      await _repository.deleteLogs();

      setState(
        LogsManagerState.idle(archive: state.archive),
      );
      onDeleted?.call();
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  void _onError(Object? error, StackTrace? stackTrace) => setState(
    LogsManagerState.error(
      ExceptionUtils.toPresentationException(exception: error),
      archive: state.archive,
    ),
  );

  void _onCompleted() => setState(
    LogsManagerState.idle(archive: state.archive),
  );
}
