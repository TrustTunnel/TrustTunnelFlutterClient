import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/data/model/routing_mode.dart';
import 'package:trusttunnel/data/model/routing_profile_data.dart';
import 'package:trusttunnel/feature/routing/routing_details/controller/routing_details_controller.dart';
import 'package:trusttunnel/feature/routing/routing_details/controller/routing_details_states.dart';
import 'package:trusttunnel/feature/routing/routing_details/domain/service/routing_details_service.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/scope/routing_details_aspect.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/scope/routing_details_controller.dart';

class RoutingDetailsScope extends StatefulWidget {
  final Widget child;
  final String? profileId;

  const RoutingDetailsScope({
    required this.child,
    required this.profileId,
    super.key,
  });

  static RoutingDetailsScopeController controllerOf(
    BuildContext context, {
    bool listen = true,
    RoutingDetailsScopeAspect? aspect,
  }) => _InheritedRoutingDetailsScope.controllerOf(
    context,
    listen: listen,
    aspect: aspect,
  );

  @override
  State<RoutingDetailsScope> createState() => _RoutingDetailsScopeState();
}

class _RoutingDetailsScopeState extends State<RoutingDetailsScope> {
  late final RoutingDetailsController _controller;
  bool _profileRequested = false;

  @override
  void initState() {
    super.initState();
    final repositoryFactory = context.repositoryFactory;

    _controller = RoutingDetailsController(
      repository: repositoryFactory.routingRepository,
      detailsService: RoutingDetailsServiceImpl(),
      profileId: widget.profileId,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profileRequested) {
      return;
    }

    _profileRequested = true;
    _fetchProfile();
  }

  @override
  Widget build(BuildContext context) => StateConsumer<RoutingDetailsController, RoutingDetailsState>(
    controller: _controller,
    builder: (context, state, _) => _InheritedRoutingDetailsScope(
      state: state,
      changeData:
          ({
            RoutingProfileData? data,
            bool? hasInvalidRules,
          }) => _controller.dataChanged(
            data: data,
            hasInvalidRules: hasInvalidRules,
          ),
      id: widget.profileId,
      clearRules: _controller.clearRules,
      fetchProfile: _fetchProfile,
      submit: _controller.submit,
      changeDefaultRoutingMode: _controller.changeDefaultRoutingMode,
      editing: widget.profileId != null,
      child: widget.child,
    ),
  );

  void _fetchProfile() {
    final ln = context.ln;
    _controller.fetch(
      defaultProfileName: ln.defaultProfile,
      formatNewProfileName: ln.newRoutingProfileName,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _InheritedRoutingDetailsScope extends InheritedModel<RoutingDetailsScopeAspect>
    implements RoutingDetailsScopeController {
  final RoutingDetailsState _state;

  const _InheritedRoutingDetailsScope({
    required this._state,
    required this.id,
    required this.changeDefaultRoutingMode,
    required this.changeData,
    required this.fetchProfile,
    required this.clearRules,
    required this.submit,
    required this.editing,
    required super.child,
  });

  @override
  final String? id;

  @override
  final bool editing;

  @override
  final RoutingDataChangedCallback changeData;

  @override
  final void Function() fetchProfile;

  @override
  final void Function(VoidCallback onCleared) clearRules;

  @override
  final void Function(VoidCallback onSaved) submit;

  @override
  final void Function(RoutingMode mode, VoidCallback onChanged) changeDefaultRoutingMode;

  @override
  RoutingProfileData? get data => _state.data;

  @override
  bool get hasInvalidRules => _state.hasInvalidRules;

  @override
  PresentationException? get error => _state.error;

  @override
  bool get loading => _state.loading;

  @override
  bool get hasChanges => data != null && (id == null || data != _state.initialData);

  @override
  bool updateShouldNotify(_InheritedRoutingDetailsScope oldWidget) => _state != oldWidget._state;

  static _InheritedRoutingDetailsScope controllerOf(
    BuildContext context, {
    bool listen = true,
    RoutingDetailsScopeAspect? aspect,
  }) => _scope(context, listen: listen, aspect: aspect) ?? _notFoundInheritedWidgetOfExactType();

  @override
  bool updateShouldNotifyDependent(
    covariant _InheritedRoutingDetailsScope oldWidget,
    Set<RoutingDetailsScopeAspect> dependencies,
  ) {
    if (dependencies.isEmpty) return updateShouldNotify(oldWidget);

    bool hasAnyChanges = false;

    for (final aspect in dependencies) {
      hasAnyChanges |= switch (aspect) {
        RoutingDetailsScopeAspect.loading => loading != oldWidget.loading,
        RoutingDetailsScopeAspect.exception => error != oldWidget.error,
        RoutingDetailsScopeAspect.data =>
          hasInvalidRules != oldWidget.hasInvalidRules || data != oldWidget.data || hasChanges != oldWidget.hasChanges,
      };

      if (hasAnyChanges) return true;
    }

    return false;
  }

  static _InheritedRoutingDetailsScope? _scope(
    BuildContext context, {
    bool listen = true,
    RoutingDetailsScopeAspect? aspect,
  }) => (listen
      ? InheritedModel.inheritFrom<_InheritedRoutingDetailsScope>(
          context,
          aspect: aspect,
        )
      : context.getElementForInheritedWidgetOfExactType<_InheritedRoutingDetailsScope>()?.widget
            as _InheritedRoutingDetailsScope?);

  static Never _notFoundInheritedWidgetOfExactType<T extends InheritedModel<RoutingDetailsScopeAspect>>() =>
      throw ArgumentError(
        'Inherited widget out of scope and not found of $T exact type',
        'out_of_scope',
      );
}
