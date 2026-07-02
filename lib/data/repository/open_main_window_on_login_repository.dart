import 'package:trusttunnel/data/datasources/open_main_window_on_login_datasource.dart';

abstract class OpenMainWindowOnLoginRepository {
  Future<bool> isEnabled();

  Future<void> enable();

  Future<void> disable();
}

class OpenMainWindowOnLoginRepositoryImpl implements OpenMainWindowOnLoginRepository {
  final OpenMainWindowOnLoginDataSource _dataSource;

  OpenMainWindowOnLoginRepositoryImpl({
    required OpenMainWindowOnLoginDataSource dataSource,
  }) : _dataSource = dataSource;

  @override
  Future<bool> isEnabled() => _dataSource.isEnabled();

  @override
  Future<void> enable() => _dataSource.setEnabled(true);

  @override
  Future<void> disable() => _dataSource.setEnabled(false);
}
