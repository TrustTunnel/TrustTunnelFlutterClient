import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/data/model/routing_profile_data.dart';

/// {@template Routings_state}
/// State representation for Routings-related operations.
/// {@endtemplate}
sealed class RoutingDetailsState {
  final RoutingProfileData data;
  final RoutingProfileData initialData;
  final bool hasInvalidRules;

  const RoutingDetailsState._({
    required this.data,
    required this.initialData,
    required this.hasInvalidRules,
  });

  const factory RoutingDetailsState.initial() = _InitialRoutingDetailsState;

  /// Initial / idle state
  const factory RoutingDetailsState.idle({
    required RoutingProfileData data,
    required RoutingProfileData initialData,
    required bool hasInvalidRules,
  }) = _IdleRoutingDetailsState;

  /// Loading state
  const factory RoutingDetailsState.loading({
    required RoutingProfileData data,
    required RoutingProfileData initialData,
    required bool hasInvalidRules,
  }) = _LoadingRoutingDetailState;

  /// Error state
  const factory RoutingDetailsState.exception({
    required RoutingProfileData data,
    required RoutingProfileData initialData,
    required bool hasInvalidRules,
    required PresentationError exception,
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
  }) : super._();
}

final class _InitialRoutingDetailsState extends _IdleRoutingDetailsState {
  const _InitialRoutingDetailsState()
    : super(
        data: const RoutingProfileData.empty(),
        initialData: const RoutingProfileData.empty(),
        hasInvalidRules: false,
      );
}

final class _LoadingRoutingDetailState extends RoutingDetailsState {
  const _LoadingRoutingDetailState({
    required super.data,
    required super.initialData,
    required super.hasInvalidRules,
  }) : super._();
}

final class _ErrorRoutingDetailState extends RoutingDetailsState {
  final PresentationError exception;

  const _ErrorRoutingDetailState({
    required this.exception,
    required super.data,
    required super.initialData,
    required super.hasInvalidRules,
  }) : super._();
}
