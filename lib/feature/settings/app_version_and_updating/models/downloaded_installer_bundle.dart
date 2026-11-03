import 'package:flutter/foundation.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/available_app_update.dart';

@immutable
final class DownloadedInstallerBundle {
  final AvailableAppUpdate update;
  final String path;

  const DownloadedInstallerBundle({
    required this.update,
    required this.path,
  });
}
