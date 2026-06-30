import '../../model/share_content.dart';
import '../prepared_share_file.dart';

Future<bool> doesShareFileExist(String filePath) async {
  throw UnimplementedError('File sharing requires dart:io support.');
}

Future<PreparedShareFile> prepareShareFile(
  ShareFile file, {
  required String mimeType,
}) async {
  throw UnimplementedError('File sharing requires dart:io support.');
}

Future<void> cleanupStaleShareFiles() async {
  throw UnimplementedError('File sharing requires dart:io support.');
}
