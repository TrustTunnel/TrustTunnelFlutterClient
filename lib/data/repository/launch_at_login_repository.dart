import 'package:trusttunnel/data/datasources/launch_at_login_datasource.dart';

abstract class LaunchAtLoginRepository {
  Future<bool> isEnabled();

  Future<void> enable();

  Future<void> disable();
}

class LaunchAtLoginRepositoryImpl implements LaunchAtLoginRepository {
  final LaunchAtLoginDataSource _dataSource;

  LaunchAtLoginRepositoryImpl({
    required this._dataSource,
  });

  @override
  Future<bool> isEnabled() => _dataSource.isEnabled();

  @override
  Future<void> enable() => _dataSource.setEnabled(true);

  @override
  Future<void> disable() => _dataSource.setEnabled(false);
}
