import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/data/repository/open_main_window_on_login_repository.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/open_main_window_on_login_state.dart';

final class OpenMainWindowOnLoginController extends BaseStateController<OpenMainWindowOnLoginState>
    with SequentialControllerHandler {
  final OpenMainWindowOnLoginRepository _repository;

  OpenMainWindowOnLoginController({
    required OpenMainWindowOnLoginRepository repository,
    super.initialState = const OpenMainWindowOnLoginState.initial(),
  }) : _repository = repository;

  void fetch() => handle(
    () async {
      setState(
        OpenMainWindowOnLoginState.loading(
          enabled: state.enabled,
        ),
      );

      final enabled = await _repository.isEnabled();

      setState(
        OpenMainWindowOnLoginState.idle(
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
        OpenMainWindowOnLoginState.loading(
          enabled: state.enabled,
        ),
      );

      if (enabled) {
        await _repository.enable();
      } else {
        await _repository.disable();
      }

      setState(
        OpenMainWindowOnLoginState.idle(
          enabled: await _repository.isEnabled(),
        ),
      );
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  void _onError(Object? error, StackTrace? stackTrace) => setState(
    OpenMainWindowOnLoginState.error(
      enabled: state.enabled,
      error: ExceptionUtils.toPresentationException(exception: error),
    ),
  );

  void _onCompleted() => setState(
    OpenMainWindowOnLoginState.idle(
      enabled: state.enabled,
    ),
  );
}
