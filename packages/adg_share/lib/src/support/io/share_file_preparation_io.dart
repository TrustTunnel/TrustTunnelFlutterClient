import 'dart:io';

import 'package:path/path.dart' as p;

import '../../model/share_content.dart';
import '../../model/share_exception.dart';
import '../prepared_share_file.dart';

const _shareTempDirectoryName = 'adg_share';
const _staleFileLifetime = Duration(hours: 12);

Future<bool> doesShareFileExist(String filePath) => File(filePath).exists();

Future<PreparedShareFile> prepareShareFile(
  ShareFile file, {
  required String mimeType,
}) async {
  final sourceFile = File(file.path);
  if (!await sourceFile.exists()) {
    throw ShareFileNotFoundException(file.path);
  }

  final normalizedFileName = _normalizeFileName(file.fileNameOverride);
  if (normalizedFileName == null || normalizedFileName == p.basename(file.path)) {
    return PreparedShareFile(path: file.path, mimeType: mimeType);
  }

  await cleanupStaleShareFiles();

  final tempDirectory = await _ensureShareDirectory();
  final targetPath = p.join(
    tempDirectory.path,
    '${DateTime.now().microsecondsSinceEpoch}_$normalizedFileName',
  );

  await sourceFile.copy(targetPath);

  return PreparedShareFile(path: targetPath, mimeType: mimeType);
}

Future<void> cleanupStaleShareFiles() async {
  final shareDirectory = await _ensureShareDirectory();
  if (!await shareDirectory.exists()) {
    return;
  }

  final threshold = DateTime.now().subtract(_staleFileLifetime);
  await for (final entity in shareDirectory.list()) {
    if (entity is! File) {
      continue;
    }

    final stat = await entity.stat();
    if (stat.modified.isBefore(threshold)) {
      await entity.delete();
    }
  }
}

Future<Directory> _ensureShareDirectory() async {
  final shareDirectory = Directory(
    p.join(Directory.systemTemp.path, _shareTempDirectoryName),
  );
  if (!await shareDirectory.exists()) {
    await shareDirectory.create(recursive: true);
  }

  return shareDirectory;
}

String? _normalizeFileName(String? fileNameOverride) {
  final normalizedFileName = fileNameOverride?.trim();
  if (normalizedFileName == null || normalizedFileName.isEmpty) {
    return null;
  }

  return normalizedFileName.replaceAll('/', '_').replaceAll('\\', '_');
}
