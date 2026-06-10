abstract interface class LogStorageDataSource {
  Future<String> readCombinedLogs();

  Future<void> deleteLogs();
}
