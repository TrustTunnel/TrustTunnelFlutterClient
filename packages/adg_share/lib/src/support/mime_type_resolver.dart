import 'package:mime/mime.dart';

final class MimeTypeResolver {
  const MimeTypeResolver();

  String resolve({
    required String filePath,
    String? explicitMimeType,
  }) {
    final normalizedMimeType = explicitMimeType?.trim();
    if (normalizedMimeType != null && normalizedMimeType.isNotEmpty) {
      return normalizedMimeType;
    }

    return lookupMimeType(filePath) ?? 'application/octet-stream';
  }
}
