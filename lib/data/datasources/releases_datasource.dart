import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/data/model/available_app_update_data.dart';

abstract interface class ReleasesDataSource {
  Future<AvailableAppUpdateData?> findAvailableUpdate(AppVersion installedVersion);

  Stream<List<int>> openInstallerBundle({
    required int assetId,
    required Future<void> cancellation,
  });
}
