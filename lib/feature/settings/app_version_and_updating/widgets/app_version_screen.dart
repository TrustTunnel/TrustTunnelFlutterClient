import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/assets_images.dart';
import 'package:trusttunnel/common/constants/app_constants.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/widgets/app_update_content.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/widgets/scope/app_version_and_updating_scope.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/widgets/scope/app_version_and_updating_scope_aspect.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/widgets/scope/app_version_and_updating_scope_controller.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/default_page.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class AppVersionScreen extends StatefulWidget {
  const AppVersionScreen({super.key});

  @override
  State<AppVersionScreen> createState() => _AppVersionScreenState();
}

class _AppVersionScreenState extends State<AppVersionScreen> {
  late AppVersion? _appVersion;
  late bool _updatesSupported;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppVersionAndUpdatingScopeController updatesController = AppVersionAndUpdatingScope.controllerOf(
      context: context,
      aspect: AppVersionAndUpdatingScopeAspect.status,
    );
    _appVersion = updatesController.version;
    _updatesSupported = updatesController.updatesSupported;
  }

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
    child: Scaffold(
      appBar: CustomAppBar(title: context.ln.appVersion),
      body: _updatesSupported
          ? SingleChildScrollView(
              padding: const EdgeInsets.only(top: 40, bottom: 16),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      AssetImages.aboutDesktop,
                      width: 300,
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 8),
                    Text(AppConstants.appName, style: context.textTheme.headlineMedium),
                    const SizedBox(height: 12),
                    Text(
                      _appVersion == null ? '' : 'v$_appVersion',
                      style: context.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    const AppUpdateContent(),
                  ],
                ),
              ),
            )
          : DefaultPage.responsive(
              title: AppConstants.appName,
              descriptionText: _appVersion == null ? null : 'v$_appVersion',
              imagePath: AssetImages.about,
              desktopImagePath: AssetImages.aboutDesktop,
            ),
    ),
  );
}
