import 'package:trusttunnel/common/controller/controller/controller.dart';
import 'package:trusttunnel/common/controller/controller/controller_observer.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/logging/app_logger.dart';

class LoggingControllerObserver implements ControllerObserver {
  final AppLogger _logger;

  const LoggingControllerObserver({
    required AppLogger logger,
  }) : _logger = logger;

  @override
  void onCreate(BaseController controller) {
    if (!_logger.isDebugLoggingEnabled) {
      return;
    }

    final controllerName = controller.runtimeType.toString();
    _logger.logDebug(
      'Controller $controllerName created',
      additionalTags: ['controller', controllerName, 'lifecycle'],
    );
  }

  @override
  void onDispose(BaseController controller) {
    if (!_logger.isDebugLoggingEnabled) {
      return;
    }

    final controllerName = controller.runtimeType.toString();
    _logger.logDebug(
      'Controller $controllerName disposed',
      additionalTags: ['controller', controllerName, 'lifecycle'],
    );
  }

  @override
  void onStateChanged<S extends Object>(
    BaseStateController<S> controller,
    S previousState,
    S nextState,
  ) {
    if (!_logger.isDebugLoggingEnabled) {
      return;
    }

    final controllerName = controller.runtimeType.toString();
    final sanitizedNewState = _logger.sanitizePayload(nextState);

    _logger.logTrace(
      'Controller $controllerName state changed, new state: $sanitizedNewState',
      additionalTags: ['controller', controllerName, 'state'],
    );
  }

  @override
  void onError(BaseController controller, Object error, StackTrace stackTrace) {
    final controllerName = controller.runtimeType.toString();
    _logger.logError(
      'Controller $controllerName error',
      error: error,
      stackTrace: stackTrace,
      additionalTags: ['controller', controllerName, 'error'],
    );
  }
}
