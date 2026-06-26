import 'package:trusttunnel/common/logging/model/app_state_snapshot.dart';

abstract interface class AppStateLoggingDataSource {
  Future<AppStateSnapshot> collectSnapshot();
}
