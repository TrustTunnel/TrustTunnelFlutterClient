import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';

/// {@template Routing_state}
/// State representation for Routing-related operations.
/// {@endtemplate}
sealed class RoutingState {
  final List<RoutingProfile> routingList;
  final List<PresentationField> fieldErrors;

  const RoutingState._({
    required this.routingList,
    required this.fieldErrors,
  });

  const factory RoutingState.initial() = _InitialRoutingState;

  /// Initial / idle state
  const factory RoutingState.idle({
    required List<RoutingProfile> routingList,
    required List<PresentationField> fieldErrors,
  }) = _IdleRoutingState;

  /// Loading state
  const factory RoutingState.loading({
    required List<RoutingProfile> routingList,
    required List<PresentationField> fieldErrors,
  }) = _LoadingRoutingState;

  /// Error state
  const factory RoutingState.exception({
    required List<RoutingProfile> routingList,
    required List<PresentationField> fieldErrors,
    required PresentationError exception,
  }) = _ErrorRoutingState;

  PresentationError? get error => this is _ErrorRoutingState ? (this as _ErrorRoutingState).exception : null;

  bool get loading => this is _LoadingRoutingState;
}

final class _IdleRoutingState extends RoutingState {
  const _IdleRoutingState({
    required super.routingList,
    required super.fieldErrors,
  }) : super._();
}

final class _InitialRoutingState extends _IdleRoutingState {
  const _InitialRoutingState()
    : super(
        routingList: const [],
        fieldErrors: const [],
      );
}

final class _LoadingRoutingState extends RoutingState {
  const _LoadingRoutingState({
    required super.routingList,
    required super.fieldErrors,
  }) : super._();
}

final class _ErrorRoutingState extends RoutingState {
  final PresentationError exception;

  const _ErrorRoutingState({
    required super.routingList,
    required super.fieldErrors,
    required this.exception,
  }) : super._();
}
