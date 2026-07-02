import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/data/repository/auto_connect_on_launch_settings_repository.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/auto_connect_on_launch_state.dart';

final class AutoConnectOnLaunchSettingsController extends BaseStateController<AutoConnectOnLaunchState>
    with SequentialControllerHandler {
  final AutoConnectOnLaunchSettingsRepository _repository;

  AutoConnectOnLaunchSettingsController({
    required AutoConnectOnLaunchSettingsRepository repository,
    super.initialState = const AutoConnectOnLaunchState.initial(),
  }) : _repository = repository;

  Future<void> fetch() => handle(
    () async {
      setState(
        AutoConnectOnLaunchState.loading(
          enabled: state.enabled,
          lastServerId: state.lastServerId,
          connectOnLaunchHandled: state.connectOnLaunchHandled,
        ),
      );

      final enabled = await _repository.isEnabled();
      final lastServerId = await _repository.getLastServerId();

      setState(
        AutoConnectOnLaunchState.idle(
          enabled: enabled,
          lastServerId: lastServerId,
          connectOnLaunchHandled: state.connectOnLaunchHandled,
        ),
      );
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  Future<void> enable() => handle(
    () async {
      setState(
        AutoConnectOnLaunchState.loading(
          enabled: state.enabled,
          lastServerId: state.lastServerId,
          connectOnLaunchHandled: state.connectOnLaunchHandled,
        ),
      );

      await _repository.enable();

      setState(
        AutoConnectOnLaunchState.idle(
          enabled: await _repository.isEnabled(),
          lastServerId: await _repository.getLastServerId(),
          connectOnLaunchHandled: state.connectOnLaunchHandled,
        ),
      );
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  Future<void> disable() => handle(
    () async {
      setState(
        AutoConnectOnLaunchState.loading(
          enabled: state.enabled,
          lastServerId: state.lastServerId,
          connectOnLaunchHandled: state.connectOnLaunchHandled,
        ),
      );

      await _repository.disable();

      setState(
        AutoConnectOnLaunchState.idle(
          enabled: await _repository.isEnabled(),
          lastServerId: await _repository.getLastServerId(),
          connectOnLaunchHandled: state.connectOnLaunchHandled,
        ),
      );
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  Future<void> setLastServerId(String? serverId) => handle(
    () async {
      setState(
        AutoConnectOnLaunchState.loading(
          enabled: state.enabled,
          lastServerId: state.lastServerId,
          connectOnLaunchHandled: state.connectOnLaunchHandled,
        ),
      );

      await _repository.setLastServerId(serverId);

      setState(
        AutoConnectOnLaunchState.idle(
          enabled: state.enabled,
          lastServerId: serverId,
          connectOnLaunchHandled: state.connectOnLaunchHandled,
        ),
      );
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  Future<void> markConnectOnLaunchHandled() => handle(
    () async {
      setState(
        AutoConnectOnLaunchState.idle(
          enabled: state.enabled,
          lastServerId: state.lastServerId,
          connectOnLaunchHandled: true,
        ),
      );
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  void _onError(Object? error, StackTrace? stackTrace) => setState(
    AutoConnectOnLaunchState.error(
      enabled: state.enabled,
      lastServerId: state.lastServerId,
      connectOnLaunchHandled: state.connectOnLaunchHandled,
      error: ExceptionUtils.toPresentationException(exception: error),
    ),
  );

  void _onCompleted() => setState(
    AutoConnectOnLaunchState.idle(
      enabled: state.enabled,
      lastServerId: state.lastServerId,
      connectOnLaunchHandled: state.connectOnLaunchHandled,
    ),
  );
}
