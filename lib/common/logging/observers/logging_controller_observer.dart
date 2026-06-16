import 'package:adguard_logger/adguard_logger.dart';
import 'package:trusttunnel/common/controller/controller/controller.dart';
import 'package:trusttunnel/common/controller/controller/controller_observer.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';

class LoggingControllerObserver implements ControllerObserver {
  const LoggingControllerObserver();

  @override
  void onCreate(BaseController controller) {
    final controllerName = _getControllerName(controller);
    logger.logTrace(
      'Controller $controllerName created',
      additionalTags: ['controller', controllerName, 'lifecycle'],
    );
  }

  @override
  void onDispose(BaseController controller) {
    final controllerName = _getControllerName(controller);
    logger.logTrace(
      'Controller $controllerName disposed',
      additionalTags: ['controller', controllerName, 'lifecycle'],
    );

    logger.logTrace(
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
    final controllerName = _getControllerName(controller);

    logger.logTrace(
      'Controller $controllerName state changed, new state: $nextState',
      additionalTags: ['controller', controllerName, 'state'],
    );
  }

  @override
  void onError(BaseController controller, Object error, StackTrace stackTrace) {
    final controllerName = _getControllerName(controller);
    logger.logError(
      'Controller $controllerName error',
      error: error,
      stackTrace: stackTrace,
      additionalTags: ['controller', controllerName, 'error'],
    );
  }

  String _getControllerName(BaseController controller) => controller.runtimeType.toString();
}
