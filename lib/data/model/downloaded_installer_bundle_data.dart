import 'package:flutter/foundation.dart';
import 'package:trusttunnel/data/model/available_app_update_data.dart';

@immutable
final class DownloadedInstallerBundleData {
  final AvailableAppUpdateData update;
  final String path;

  const DownloadedInstallerBundleData({
    required this.update,
    required this.path,
  });
}
