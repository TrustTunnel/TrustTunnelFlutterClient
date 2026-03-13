import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/utils/routing_profile_utils.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server_data.dart';
import 'package:trusttunnel/feature/server/server_details/controller/servers_details_controller.dart';
import 'package:trusttunnel/feature/server/server_details/controller/servers_details_states.dart';
import 'package:trusttunnel/feature/server/server_details/domain/service/server_details_service.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/scope/server_details_scope_aspect.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/scope/server_details_scope_controller.dart';

/// {@template products_scope_template}
/// Provides Products controller to the widget tree
/// {@endtemplate}
class ServerDetailsScope extends StatefulWidget {
  final Widget child;
  final ServerData? initialData;
  final String? serverId;

  /// {@macro products_scope_template}
  const ServerDetailsScope({
    required this.child,
    required this.serverId,
    this.initialData,
    super.key,
  });

  /// Get the controller from context
  static ServerDetailsScopeController controllerOf(
    BuildContext context, {
    bool listen = true,
    ServerDetailsScopeAspect? aspect,
  }) => _InheritedServerDetailsScope.serversControllerOf(context, listen: listen, aspect: aspect);

  @override
  State<ServerDetailsScope> createState() => _ServerDetailsScopeState();
}

class _ServerDetailsScopeState extends State<ServerDetailsScope> {
  late final ServerDetailsController _controller;

  @override
  void initState() {
    super.initState();
    final repositoryFactory = context.repositoryFactory;

    _controller = ServerDetailsController(
      routingRepository: repositoryFactory.routingRepository,
      repository: repositoryFactory.serverRepository,
      detailsService: ServerDetailsServiceImpl(),
      serverId: widget.serverId,
      initialState: ServerDetailsState.initial(
        data:
            widget.initialData ??
            const ServerData.empty().copyWith(
              routingProfileId: RoutingProfileUtils.defaultRoutingProfileId,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StateConsumer<ServerDetailsController, ServerDetailsState>(
    controller: _controller,
    builder: (context, state, _) => _InheritedServerDetailsScope(
      state: state,
      changeData: _controller.dataChanged,
      delete: _controller.delete,
      fetchServer: _controller.fetch,
      submit: _controller.submit,
      editing: widget.serverId != null,
      id: widget.serverId,
      pickPemCertificate: _controller.pickPemCertificate,
      clearPemCertificate: _controller.clearPemCertificate,
      child: widget.child,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _InheritedServerDetailsScope extends InheritedModel<ServerDetailsScopeAspect>
    implements ServerDetailsScopeController {
  @override
  final bool editing;

  @override
  final String? id;

  @override
  final DataChangedCallback changeData;

  @override
  final void Function() fetchServer;

  @override
  final void Function() pickPemCertificate;

  @override
  final void Function() clearPemCertificate;

  @override
  final void Function(ValueChanged<String> onSaved) delete;

  @override
  final void Function(ValueChanged<String> onSaved) submit;

  final ServerDetailsState _state;

  const _InheritedServerDetailsScope({
    required ServerDetailsState state,
    required this.changeData,
    required this.fetchServer,
    required this.delete,
    required this.submit,
    required this.editing,
    required this.id,
    required this.pickPemCertificate,
    required this.clearPemCertificate,
    required super.child,
  }) : _state = state;

  static _InheritedServerDetailsScope serversControllerOf(
    BuildContext context, {
    bool listen = true,
    ServerDetailsScopeAspect? aspect,
  }) => _productsScope(context, listen: listen, aspect: aspect) ?? _notFoundInheritedWidgetOfExactType();

  static _InheritedServerDetailsScope? _productsScope(
    BuildContext context, {
    bool listen = true,
    ServerDetailsScopeAspect? aspect,
  }) => (listen
      ? InheritedModel.inheritFrom<_InheritedServerDetailsScope>(
          context,
          aspect: aspect,
        )
      : context.getElementForInheritedWidgetOfExactType<_InheritedServerDetailsScope>()?.widget
            as _InheritedServerDetailsScope?);

  static Never _notFoundInheritedWidgetOfExactType<T extends InheritedModel<ServerDetailsScopeAspect>>() =>
      throw ArgumentError(
        'Inherited widget out of scope and not found of $T exact type',
        'out_of_scope',
      );

  @override
  ServerData get data => _state.data;

  @override
  List<PresentationField> get fieldErrors => [..._state.fieldErrors];

  @override
  List<RoutingProfile> get routingProfiles => [..._state.routingProfiles];

  @override
  PresentationError? get error => _state.error;

  @override
  bool get loading => _state.loading || routingProfiles.isEmpty;

  @override
  bool get hasChanges => _state.data != _state.initialData;

  @override
  bool updateShouldNotify(_InheritedServerDetailsScope oldWidget) => _state != oldWidget._state;

  @override
  bool updateShouldNotifyDependent(
    covariant _InheritedServerDetailsScope oldWidget,
    Set<ServerDetailsScopeAspect> dependencies,
  ) {
    if (dependencies.isEmpty) return updateShouldNotify(oldWidget);

    bool hasAnyChanges = false;

    for (final aspect in dependencies) {
      hasAnyChanges |= switch (aspect) {
        ServerDetailsScopeAspect.loading => loading != oldWidget.loading,
        ServerDetailsScopeAspect.exception => error != oldWidget.error,
        ServerDetailsScopeAspect.fieldErrors => !listEquals(fieldErrors, oldWidget.fieldErrors),
        ServerDetailsScopeAspect.data =>
          _state.data != oldWidget._state.data || !listEquals(routingProfiles, oldWidget.routingProfiles),
      };

      if (hasAnyChanges) {
        return hasAnyChanges;
      }
    }

    return false;
  }
}
