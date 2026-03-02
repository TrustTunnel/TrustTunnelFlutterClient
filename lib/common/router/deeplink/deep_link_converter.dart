import 'dart:convert';


abstract class DeepLinkConverter extends Converter<Uri, String> {
  const DeepLinkConverter();
}

class CustomDeepLinkConverter extends DeepLinkConverter {
  static const deepLinkUrl = 'tt://';

  @override
  String convert(Uri uriLink) => '';

  String extractPath(Uri uriLink) => uriLink.toString().replaceAll(deepLinkUrl, '');
}
