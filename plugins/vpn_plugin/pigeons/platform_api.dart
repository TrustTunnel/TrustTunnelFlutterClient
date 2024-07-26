import 'package:pigeon/pigeon.dart';

enum VpnProtocol {
  quiq,
  http2,
}

enum RoutingMode {
  bypass,
  vpn,
}

enum VpnManagerState {
  disconnected,
  connecting,
  connected,
}

enum PlatformErrorCode {
  unknown,
}

enum PlatformFieldErrorCode {
  fieldWrongValue,
  alreadyExists,
}

enum PlatformFieldName {
  ipAddress,
  domain,
  serverName,
  dnsServers,
}

class Server {
  final int id;
  final String name;
  final String ipAddress;
  final String domain;
  final String login;
  final String password;
  final VpnProtocol vpnProtocol;
  final int routingProfileId;
  final List<String?> dnsServers;

  const Server({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.domain,
    required this.login,
    required this.password,
    required this.vpnProtocol,
    required this.routingProfileId,
    required this.dnsServers,
  });
}

class RoutingProfile {
  final int id;
  final String name;
  final RoutingMode defaultMode;
  final List<String?> bypassRules;
  final List<String?> vpnRules;

  const RoutingProfile({
    required this.id,
    required this.name,
    required this.defaultMode,
    required this.bypassRules,
    required this.vpnRules,
  });
}

class VpnRequest {
  final String time;
  final VpnProtocol vpnProtocol;
  final RoutingMode decision;
  final String sourceIpAddress;
  final String destinationIpAddress;
  final String? sourcePort;
  final String? destinationPort;
  final String? domain;

  const VpnRequest({
    required this.time,
    required this.vpnProtocol,
    required this.decision,
    required this.sourceIpAddress,
    required this.destinationIpAddress,
    this.sourcePort,
    this.destinationPort,
    this.domain,
  });
}

class AddServerRequest {
  final String name;
  final String ipAddress;
  final String domain;
  final String login;
  final String password;
  final VpnProtocol vpnProtocol;
  final int routingProfileId;
  final List<String?> dnsServers;

  const AddServerRequest({
    required this.name,
    required this.ipAddress,
    required this.domain,
    required this.login,
    required this.password,
    required this.vpnProtocol,
    required this.routingProfileId,
    required this.dnsServers,
  });
}

class UpdateServerRequest {
  final int id;
  final String name;
  final String ipAddress;
  final String domain;
  final String login;
  final String password;
  final VpnProtocol vpnProtocol;
  final int routingProfileId;
  final List<String?> dnsServers;

  const UpdateServerRequest({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.domain,
    required this.login,
    required this.password,
    required this.vpnProtocol,
    required this.routingProfileId,
    required this.dnsServers,
  });
}

class AddRoutingProfileRequest {
  final String name;
  final RoutingMode defaultMode;
  final List<String?> bypassRules;
  final List<String?> vpnRules;

  const AddRoutingProfileRequest({
    required this.name,
    required this.defaultMode,
    required this.bypassRules,
    required this.vpnRules,
  });
}

class UpdateRoutingProfileRequest {
  final String id;
  final String name;
  final RoutingMode defaultMode;
  final List<String?> bypassRules;
  final List<String?> vpnRules;

  const UpdateRoutingProfileRequest({
    required this.id,
    required this.name,
    required this.defaultMode,
    required this.bypassRules,
    required this.vpnRules,
  });
}

class PlatformErrorResponse {
  final PlatformErrorCode? code;
  final List<PlatformFieldError?>? fieldErrors;

  const PlatformErrorResponse({
    this.code,
    this.fieldErrors,
  });
}

class PlatformFieldError {
  final PlatformFieldErrorCode code;
  final PlatformFieldName fieldName;

  const PlatformFieldError({
    required this.code,
    required this.fieldName,
  });
}

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/platform_api.g.dart',
  dartOptions: DartOptions(),
  cppOptions: CppOptions(namespace: 'vpn_plugin'),
  cppHeaderOut: 'windows/runner/platform_api.g.h',
  cppSourceOut: 'windows/runner/platform_api.g.cpp',
  kotlinOut: 'android/src/main/kotlin/com/example/vpn_plugin/PlatformApi.g.kt',
  kotlinOptions: KotlinOptions(
    package: 'com.example.vpn_plugin',
  ),
  swiftOptions: SwiftOptions(),
))
@HostApi()
abstract class PlatformApi {
  // Storage Manager
  List<Server> getAllServers();

  Server getServerById({required int id});

  Server addServer({required AddServerRequest request});

  Server updateServer({required UpdateServerRequest request});

  void removeServer({required int id});

  int? getSelectedServerId();

  void setSelectedServerId({required int id});

  List<RoutingProfile> getAllRoutingProfiles();

  RoutingProfile getRoutingProfileById({required int id});

  RoutingProfile addRoutingProfile({required AddRoutingProfileRequest request});

  RoutingProfile updateRoutingProfile({required UpdateRoutingProfileRequest request});

  void setRoutingProfileName({required String name});

  void removeRoutingProfile({required int id});

  List<VpnRequest> getAllRequests();

  void setExcludedRoutes(String routes);

  String getExcludedRoutes();

  // VPN manager
  void start();

  void stop();

  VpnManagerState getCurrentState();

  // Common
  void errorStub(PlatformErrorResponse error);
}
