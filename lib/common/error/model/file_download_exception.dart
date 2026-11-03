final class FileDownloadCancelledException implements Exception {
  const FileDownloadCancelledException();
}

final class FileDownloadSizeException implements Exception {
  const FileDownloadSizeException();
}

final class FileDownloadCleanupException implements Exception {
  final Object cause;
  final Object cleanupError;

  const FileDownloadCleanupException({required this.cause, required this.cleanupError});

  @override
  String toString() => 'FileDownloadCleanupException: $cause; cleanup: $cleanupError';
}
