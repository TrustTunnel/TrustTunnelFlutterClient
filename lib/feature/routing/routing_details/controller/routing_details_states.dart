import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/feature/routing/routing_details/model/routing_details_data.dart';

/// {@template Routings_state}
/// State representation for Routings-related operations.
/// {@endtemplate}
sealed class RoutingDetailsState {
  final RoutingDetailsData data;
  final RoutingDetailsData initialData;
  final bool hasInvalidRules;
  final String name;

  const RoutingDetailsState._({
    required this.data,
    required this.initialData,
    required this.hasInvalidRules,
    required this.name,
  });

  const factory RoutingDetailsState.initial() = _InitialRoutingDetailsState;

  /// Initial / idle state
  const factory RoutingDetailsState.idle({
    required RoutingDetailsData data,
    required RoutingDetailsData initialData,
    required bool hasInvalidRules,
    required String name,
  }) = _IdleRoutingDetailsState;

  /// Loading state
  const factory RoutingDetailsState.loading({
    required RoutingDetailsData data,
    required RoutingDetailsData initialData,
    required bool hasInvalidRules,
    required String name,
  }) = _LoadingRoutingDetailState;

  /// Error state
  const factory RoutingDetailsState.exception({
    required RoutingDetailsData data,
    required RoutingDetailsData initialData,
    required bool hasInvalidRules,
    required PresentationError exception,
    required String name,
  }) = _ErrorRoutingDetailState;

  PresentationError? get error => this is _ErrorRoutingDetailState ? (this as _ErrorRoutingDetailState).error : null;

  bool get loading => this is _LoadingRoutingDetailState;

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    data,
    initialData,
    error,
    loading,
    hasInvalidRules,
  ]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutingDetailsState &&
          runtimeType == other.runtimeType &&
          data == other.data &&
          initialData == other.initialData &&
          error == other.error &&
          hasInvalidRules == other.hasInvalidRules &&
          loading == other.loading;
}

final class _IdleRoutingDetailsState extends RoutingDetailsState {
  const _IdleRoutingDetailsState({
    required super.data,
    required super.initialData,
    required super.hasInvalidRules,
    required super.name,
  }) : super._();
}

final class _InitialRoutingDetailsState extends _IdleRoutingDetailsState {
  const _InitialRoutingDetailsState()
    : super(
        data: const RoutingDetailsData(),
        initialData: const RoutingDetailsData(),
        hasInvalidRules: false,
        name: '',
      );
}

final class _LoadingRoutingDetailState extends RoutingDetailsState {
  const _LoadingRoutingDetailState({
    required super.data,
    required super.initialData,
    required super.hasInvalidRules,
    required super.name,
  }) : super._();
}

final class _ErrorRoutingDetailState extends RoutingDetailsState {
  final PresentationError exception;

  const _ErrorRoutingDetailState({
    required this.exception,
    required super.data,
    required super.initialData,
    required super.hasInvalidRules,
    required super.name,
  }) : super._();
}
