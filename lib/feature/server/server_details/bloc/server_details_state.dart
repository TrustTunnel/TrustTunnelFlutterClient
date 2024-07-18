part of 'server_details_bloc.dart';

@freezed
sealed class ServerDetailsState with _$ServerDetailsState {
  const ServerDetailsState._();

  const factory ServerDetailsState({
    int? serverId,
    @Default(ServerDetailsData()) ServerDetailsData data,
    @Default(ServerDetailsData()) ServerDetailsData initialData,
    @Default(VpnProtocol.values) List<VpnProtocol> availableProtocols,
    @Default(ServerDetailsLoadingStatus.initialLoading)
    ServerDetailsLoadingStatus loadingStatus,
  }) = _ServersDetailsState;
}

enum ServerDetailsLoadingStatus {
  initialLoading,
  loading,
  error,
  idle,
}
