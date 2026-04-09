import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/error_utils.dart';
import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/data/model/server_data.dart';
import 'package:trusttunnel/data/repository/deep_link_repository.dart';
import 'package:trusttunnel/feature/deep_link/controller/deep_link_state.dart';

const _deepLinkScheme = 'tt';

/// {@template products_controller}
/// Controller for managing products and purchase operations.
/// {@endtemplate}
final class DeepLinkController extends BaseStateController<DeepLinkState> with SequentialControllerHandler {
  final DeepLinkRepository _repository;

  /// {@macro products_controller}
  DeepLinkController({
    required DeepLinkRepository repository,
    super.initialState = const DeepLinkState.initial(),
  }) : _repository = repository;

  void onDeepLinkReceived(Uri? deepLink) => handle(
    () async {
      setState(
        DeepLinkState.loading(
          state.parsedData,
        ),
      );

      ServerData? parsedDeepLink;

      if (deepLink?.hasQuery ?? false) {
        parsedDeepLink = await _repository.parseDataFromLink(
          deepLink: Uri(
            scheme: _deepLinkScheme,
            host: '',
            query: deepLink!.query,
          ).toString(),
        );
      }

      setState(
        DeepLinkState.idle(parsedDeepLink),
      );
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  PresentationError _parseException(Object? exception) => ErrorUtils.toPresentationError(exception: exception);

  Future<void> _onError(Object? error, StackTrace _) async {
    final presentationException = _parseException(error);

    setState(
      DeepLinkState.exception(
        state.parsedData,
        exception: presentationException,
      ),
    );
  }

  Future<void> _onCompleted() async => setState(
    DeepLinkState.idle(state.parsedData),
  );
}
