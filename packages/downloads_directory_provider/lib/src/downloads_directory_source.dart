import 'dart:io';

/// Provides the platform-specific directory where downloaded/exported files
/// should be saved.
///
/// - Android: public Downloads folder via native [MethodChannel].
/// - iOS: application documents directory (shared via Share Sheet).
/// - Desktop: system Downloads folder via [path_provider].
abstract interface class DownloadsDirectorySource {
  Future<Directory> getDirectory();
}
