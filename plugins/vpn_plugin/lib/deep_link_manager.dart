import 'dart:convert';

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
  final IDeepLink _deepLinkParser;
  final Codec<Configuration, String> _codec;
  final ConfigurationSectionConverter<Endpoint, String> _endpointEncoder;

  const DeepLinkManagerImpl({
    required IDeepLink deepLinkParser,
    required Codec<Configuration, String> codec,
    required ConfigurationSectionConverter<Endpoint, String> endpointEncoder,
  }) : _deepLinkParser = deepLinkParser,
       _codec = codec,
       _endpointEncoder = endpointEncoder;

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
