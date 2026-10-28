import 'package:flutter/material.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/widgets/scope/app_version_and_updating_scope.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/widgets/scope/app_version_and_updating_scope_aspect.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/widgets/scope/app_version_and_updating_scope_controller.dart';
import 'package:trusttunnel/widgets/custom_snack_bar.dart';

class AppUpdateNotificationListener extends StatefulWidget {
  final Widget child;

  const AppUpdateNotificationListener({
    required this.child,
    super.key,
  });

  @override
  State<AppUpdateNotificationListener> createState() => _AppUpdateNotificationListenerState();
}

class _AppUpdateNotificationListenerState extends State<AppUpdateNotificationListener> {
  late AppVersionAndUpdatingScopeController _updatesController;
  bool _notificationScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updatesController = AppVersionAndUpdatingScope.controllerOf(
      context: context,
      aspect: AppVersionAndUpdatingScopeAspect.status,
    );

    if (_updatesController.updatedVersion == null) {
      _notificationScheduled = false;

      return;
    }

    if (_notificationScheduled) {
      return;
    }

    _notificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showUpdateNotification());
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _showUpdateNotification() {
    if (!mounted) {
      return;
    }

    final String? updatedVersion = _updatesController.updatedVersion;

    if (updatedVersion == null) {
      _notificationScheduled = false;

      return;
    }

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        CustomSnackBar(
          content: Text(context.ln.updatedToVersion(updatedVersion)),
          showCloseIcon: true,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    _updatesController.removeUpdateNotification();
  }
}
