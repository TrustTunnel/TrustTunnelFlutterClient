import 'package:pigeon/pigeon.dart';

class GetPlatformTypeRequest {
  int? testParam;
}

class GetPlatformTypeResponse {
  String? platformType;
}

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/api.dart',
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
  GetPlatformTypeResponse getPlatformType(GetPlatformTypeRequest request);
}
