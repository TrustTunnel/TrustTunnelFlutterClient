import 'package:flutter/foundation.dart';
import 'package:trusttunnel/data/model/available_app_update_data.dart';

@immutable
final class AppReleasePageData {
  final AvailableAppUpdateData? update;
  final int count;

  const AppReleasePageData({required this.update, required this.count});
}
