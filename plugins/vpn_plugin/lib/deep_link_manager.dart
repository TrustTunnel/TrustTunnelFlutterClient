import 'package:vpn_plugin/domain/configuration_encoder.dart';
import 'package:vpn_plugin/models/configuration.dart';
import 'package:vpn_plugin/platform_api.g.dart';

abstract class DeepLinkManager {
  Future<Configuration> getConfigurationByBase64({
    required String base64,
  });
}

class DeepLinkManagerImpl implements DeepLinkManager {
  DeepLinkManagerImpl() : _deepLinkParser = IDeepLink(), _codec = const ConfigurationCodec();

  final ConfigurationCodec _codec;
  final IDeepLink _deepLinkParser;

  @override
  Future<Configuration> getConfigurationByBase64({required String base64}) async {
    final result = await _deepLinkParser.decode(uri: base64);
    final decodeResult = _codec.decode(result);

    return decodeResult;
  }
}
