import 'package:vpn_plugin/domain/configuration_codec.dart';
import 'package:vpn_plugin/models/configuration.dart';
import 'package:vpn_plugin/models/endpoint.dart';
import 'package:vpn_plugin/platform_api.g.dart';

abstract class DeepLinkManager {
  Future<String> createLink({required Endpoint endpoint});

  Future<Configuration> getConfigurationByBase64({
    required String base64,
  });
}

class DeepLinkManagerImpl implements DeepLinkManager {
  DeepLinkManagerImpl({
    ConfigurationSectionConverter<Endpoint, String> endpointEncoder = const EndpointEncoder(),
  }) : _deepLinkParser = IDeepLink(),
       _codec = const ConfigurationCodec(),
       _endpointEncoder = endpointEncoder;

  final ConfigurationCodec _codec;
  final IDeepLink _deepLinkParser;
  final ConfigurationSectionConverter<Endpoint, String> _endpointEncoder;

  @override
  Future<String> createLink({required Endpoint endpoint}) => _deepLinkParser.encode(
    endpointToml: _endpointEncoder.convert(endpoint),
  );

  @override
  Future<Configuration> getConfigurationByBase64({required String base64}) async {
    final result = await _deepLinkParser.decode(uri: base64);
    final decodeResult = _codec.decode(result);

    return decodeResult;
  }
}
