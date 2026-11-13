import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/data/repository/ru_bypass_repository.dart';
import 'package:trusttunnel/feature/settings/ru_bypass/controller/ru_bypass_states.dart';

/// {@template ru_bypass_controller}
/// Controller for the Runet bypass settings.
/// {@endtemplate}
final class RuBypassController extends BaseStateController<RuBypassState> with SequentialControllerHandler {
  final RuBypassRepository _repository;

  /// Cached CIDR list; kept in sync with the stored one.
  List<String> _cidrList = const [];

  /// {@macro ru_bypass_controller}
  RuBypassController(
    this._repository, {
    super.initialState = const RuBypassState.initial(),
  });

  /// Stored CIDR entries merged into the effective VPN exclusions.
  List<String> get cidrList => _cidrList;

  void fetch() {
    handle(
      () async {
        setState(
          RuBypassState.loading(
            enabled: state.enabled,
            lastUpdateDate: state.lastUpdateDate,
            cidrCount: state.cidrCount,
          ),
        );

        final persisted = await _repository.getState();
        _cidrList = await _repository.getCidrList();

        setState(
          RuBypassState.idle(
            enabled: persisted.enabled,
            lastUpdateDate: persisted.lastUpdateDate,
            cidrCount: persisted.cidrCount,
          ),
        );
      },
      errorHandler: _onError,
      completionHandler: _onCompleted,
    );
  }

  /// Toggles Runet bypass. Persisted immediately.
  void setEnabled(bool enabled) => handle(
    () async {
      setState(
        RuBypassState.idle(
          enabled: enabled,
          lastUpdateDate: state.lastUpdateDate,
          cidrCount: state.cidrCount,
        ),
      );

      await _repository.setEnabled(enabled);
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  /// Re-downloads the RU CIDR list. Persisted immediately.
  void updateLists({required void Function(int cidrCount) onSuccess}) => handle(
    () async {
      setState(
        RuBypassState.loading(
          enabled: state.enabled,
          lastUpdateDate: state.lastUpdateDate,
          cidrCount: state.cidrCount,
        ),
      );

      final result = await _repository.updateLists();
      _cidrList = await _repository.getCidrList();

      setState(
        RuBypassState.idle(
          enabled: state.enabled,
          lastUpdateDate: result.updatedAt,
          cidrCount: result.cidrCount,
        ),
      );

      onSuccess(result.cidrCount);
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  Future<void> _onError(Object? error, StackTrace _) async {
    final presentationException = ExceptionUtils.toPresentationException(exception: error);

    setState(
      RuBypassState.exception(
        exception: presentationException,
        enabled: state.enabled,
        lastUpdateDate: state.lastUpdateDate,
        cidrCount: state.cidrCount,
      ),
    );
  }

  Future<void> _onCompleted() async => setState(
    RuBypassState.idle(
      enabled: state.enabled,
      lastUpdateDate: state.lastUpdateDate,
      cidrCount: state.cidrCount,
    ),
  );
}
