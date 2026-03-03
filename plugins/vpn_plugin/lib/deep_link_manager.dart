import 'package:vpn_plugin/models/configuration.dart';
import 'package:vpn_plugin/platform_api.g.dart';

abstract class DeepLinkManager {
  Future<Configuration> getConfigurationByBase64({
    required String base64,
  });
}

class DeepLinkManagerImpl implements DeepLinkManager {
  DeepLinkManagerImpl() : _deepLinkParser = IDeepLink();

  final IDeepLink _deepLinkParser;

  @override
  Future<Configuration> getConfigurationByBase64({required String base64}) async {
    final result = await _deepLinkParser.decode(uri: base64);
    print(result);
    throw UnimplementedError();
  }
}
