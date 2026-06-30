import 'package:adg_share/adg_share.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/data/repository/export_logs_repository.dart';
import 'package:trusttunnel/feature/settings/logs_manager/controller/logs_manager_state.dart';
import 'package:trusttunnel/feature/settings/logs_manager/model/export_logs_archive.dart';

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
    ValueChanged<ExportLogsArchive>? onArchiveReady,
    VoidCallback? onError,
    VoidCallback? onCancelled,
  }) => handle(
    () async {
      setState(
        const LogsManagerState.loading(),
      );

      final archive = await _repository.createArchive();

      final result = await _repository.pickFilePath(
        dialogTitle: 'Export app logs and system info',
        fileName: archive.name,
        allowedExtensions: ['zip'],
        data: archive.data,
      );

      if (result != null) {
        onArchiveReady?.call(archive);
      } else {
        onCancelled?.call();
      }

      setState(
        const LogsManagerState.idle(),
      );
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
    required ExportLogsArchive archive,
    VoidCallback? onUnavailable,
  }) => handle(
    () async {
      setState(
        const LogsManagerState.loading(),
      );

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/${archive.name}';

      await _repository.saveRawFile(
        data: archive.data,
        path: filePath,
      );

      await _shareClient.share(
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
