import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/feature/server/server_details/model/server_details_data.dart';

/// {@template Servers_state}
/// State representation for Servers-related operations.
/// {@endtemplate}
sealed class ServerDetailsState {
  final ServerDetailsData data;
  final ServerDetailsData initialData;
  final List<PresentationField> fieldErrors;

  final List<RoutingProfile> routingProfiles;

  const ServerDetailsState._({
    required this.data,
    required this.initialData,
    required this.fieldErrors,
    required this.routingProfiles,
  });

  const factory ServerDetailsState.initial() = _InitialServerDetailsState;

  /// Initial / idle state
  const factory ServerDetailsState.idle({
    required ServerDetailsData data,
    required ServerDetailsData initialData,
    required List<PresentationField> fieldErrors,
    required List<RoutingProfile> routingProfiles,
  }) = _IdleServerDetailsState;

  /// Loading state
  const factory ServerDetailsState.loading({
    required ServerDetailsData data,
    required ServerDetailsData initialData,
    required List<PresentationField> fieldErrors,
    required List<RoutingProfile> routingProfiles,
  }) = _LoadingServerDetailState;

  /// Error state
  const factory ServerDetailsState.exception({
    required ServerDetailsData data,
    required ServerDetailsData initialData,
    required List<PresentationField> fieldErrors,
    required PresentationError exception,
    required List<RoutingProfile> routingProfiles,
  }) = _ErrorServerDetailState;

  PresentationError? get error => this is _ErrorServerDetailState ? (this as _ErrorServerDetailState).error : null;

  bool get loading => this is _LoadingServerDetailState;

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    data,
    initialData,
    fieldErrors,
    routingProfiles,
    error,
    loading,
  ]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerDetailsState &&
          runtimeType == other.runtimeType &&
          data == other.data &&
          initialData == other.initialData &&
          fieldErrors == other.fieldErrors &&
          routingProfiles == other.routingProfiles &&
          error == other.error &&
          loading == other.loading;
}

final class _IdleServerDetailsState extends ServerDetailsState {
  const _IdleServerDetailsState({
    required super.data,
    required super.initialData,
    required super.fieldErrors,
    required super.routingProfiles,
  }) : super._();
}

final class _InitialServerDetailsState extends _IdleServerDetailsState {
  const _InitialServerDetailsState()
    : super(
        data: const ServerDetailsData(),
        initialData: const ServerDetailsData(),
        fieldErrors: const [],
        routingProfiles: const [],
      );
}

final class _LoadingServerDetailState extends ServerDetailsState {
  const _LoadingServerDetailState({
    required super.data,
    required super.initialData,
    required super.fieldErrors,
    required super.routingProfiles,
  }) : super._();
}

final class _ErrorServerDetailState extends ServerDetailsState {
  final PresentationError exception;

  const _ErrorServerDetailState({
    required this.exception,
    required super.data,
    required super.initialData,
    required super.fieldErrors,
    required super.routingProfiles,
  }) : super._();
}
