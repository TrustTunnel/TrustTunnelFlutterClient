import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/data/repository/launch_at_login_repository.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/launch_at_login_state.dart';

final class LaunchAtLoginController extends BaseStateController<LaunchAtLoginState> with SequentialControllerHandler {
  final LaunchAtLoginRepository _repository;

  LaunchAtLoginController({
    required LaunchAtLoginRepository repository,
    super.initialState = const LaunchAtLoginState.initial(),
  }) : _repository = repository;

  void fetch() => handle(
    () async {
      setState(
        LaunchAtLoginState.loading(
          enabled: state.enabled,
        ),
      );

      final enabled = await _repository.isEnabled();

      setState(
        LaunchAtLoginState.idle(
          enabled: enabled,
        ),
      );
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  void enable() => _applyEnabled(enabled: true);

  void disable() => _applyEnabled(enabled: false);

  void _applyEnabled({required bool enabled}) => handle(
    () async {
      setState(
        LaunchAtLoginState.loading(
          enabled: state.enabled,
        ),
      );

      if (enabled) {
        await _repository.enable();
      } else {
        await _repository.disable();
      }
      final actualEnabled = await _repository.isEnabled();

      setState(
        LaunchAtLoginState.idle(
          enabled: actualEnabled,
        ),
      );
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  void _onError(Object? error, StackTrace? stackTrace) => setState(
    LaunchAtLoginState.error(
      enabled: state.enabled,
      error: ExceptionUtils.toPresentationException(exception: error),
    ),
  );

  void _onCompleted() => setState(
    LaunchAtLoginState.idle(
      enabled: state.enabled,
    ),
  );
}
