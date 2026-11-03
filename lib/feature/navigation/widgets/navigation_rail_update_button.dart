import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/widgets/scope/app_version_and_updating_scope.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/widgets/scope/app_version_and_updating_scope_aspect.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/widgets/scope/app_version_and_updating_scope_controller.dart';
import 'package:trusttunnel/widgets/custom_icon.dart';

class NavigationRailUpdateButton extends StatefulWidget {
  final VoidCallback onPressed;

  const NavigationRailUpdateButton({
    super.key,
    required this.onPressed,
  });

  @override
  State<NavigationRailUpdateButton> createState() => _NavigationRailUpdateButtonState();
}

class _NavigationRailUpdateButtonState extends State<NavigationRailUpdateButton> {
  late bool _updatesSupported;
  late bool _showUpdateIndicator;
  late bool _updating;
  late bool _isUpdatingFailed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final AppVersionAndUpdatingScopeController updatesController = AppVersionAndUpdatingScope.controllerOf(
      context: context,
      aspect: AppVersionAndUpdatingScopeAspect.status,
    );

    _updatesSupported = updatesController.updatesSupported;
    _showUpdateIndicator = updatesController.showUpdateIndicator;
    _updating = updatesController.updating;
    _isUpdatingFailed = updatesController.error != null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_updatesSupported || !_showUpdateIndicator) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextButton(
        style: (context.theme.textButtonTheme.style ?? const ButtonStyle()).copyWith(
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
          minimumSize: const WidgetStatePropertyAll(Size(64, 64)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: widget.onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_updating)
              SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  strokeCap: StrokeCap.round,
                  backgroundColor: context.colors.transparent,
                ),
              )
            else
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const CustomIcon(
                    icon: AssetIcons.fileDownload,
                    size: 20,
                  ),
                  if (_isUpdatingFailed)
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: SizedBox.square(
                        dimension: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.colors.backgroundSystem,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: CustomIcon(
                              icon: AssetIcons.attention,
                              size: 10.5,
                              color: context.colors.attention,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              context.ln.updateAction,
              style: context.textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
