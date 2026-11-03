/// Failure of an update operation before it is presented to the user.
sealed class AppUpdateFailure implements Exception {
  final Object cause;

  const AppUpdateFailure(this.cause);

  @override
  String toString() => '$runtimeType: $cause';
}

final class AppUpdateCheckFailure extends AppUpdateFailure {
  const AppUpdateCheckFailure(super.cause);
}

final class AppUpdateDownloadFailure extends AppUpdateFailure {
  const AppUpdateDownloadFailure(super.cause);
}

final class AppUpdateDamagedFailure extends AppUpdateFailure {
  const AppUpdateDamagedFailure(super.cause);
}

final class AppUpdatePermissionFailure extends AppUpdateFailure {
  const AppUpdatePermissionFailure(super.cause);
}

final class AppUpdateInstallationFailure extends AppUpdateFailure {
  const AppUpdateInstallationFailure(super.cause);
}

final class AppUpdateCancelledFailure extends AppUpdateFailure {
  const AppUpdateCancelledFailure(super.cause);
}
