import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/exception/app_update_exception.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/available_app_update.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/widgets/scope/app_version_and_updating_scope.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/widgets/scope/app_version_and_updating_scope_aspect.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/widgets/scope/app_version_and_updating_scope_controller.dart';
import 'package:trusttunnel/widgets/custom_icon.dart';

class AppUpdateContent extends StatefulWidget {
  const AppUpdateContent({super.key});

  @override
  State<AppUpdateContent> createState() => _AppUpdateContentState();
}

class _AppUpdateContentState extends State<AppUpdateContent> {
  late AppVersionAndUpdatingScopeController _controller;
  late AvailableAppUpdate? _availableUpdate;
  late AppUpdateException? _error;
  late bool _updating;
  late bool _checkingForUpdates;
  late bool _isUpToDate;
  late bool _initialLoadCompleted;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = AppVersionAndUpdatingScope.controllerOf(
      context: context,
      aspect: AppVersionAndUpdatingScopeAspect.status,
    );
    _availableUpdate = _controller.availableUpdate;
    _error = _controller.error;
    _updating = _controller.updating;
    _checkingForUpdates = _controller.checkingForUpdates;
    _isUpToDate = _controller.isUpToDate;
    _initialLoadCompleted = _controller.initialLoadCompleted;
  }

  @override
  Widget build(BuildContext context) {
    if (_updating) {
      return const _AppUpdateDownloadProgress();
    }

    if (_checkingForUpdates) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                strokeCap: StrokeCap.round,
                backgroundColor: context.colors.transparent,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                context.ln.checkingForUpdates,
                style: context.textTheme.bodyMedium?.copyWith(color: context.colors.neutralDark),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      final String? title = _error!.toLocalizedTitle(context);

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomIcon(
                  icon: AssetIcons.attention,
                  size: 16,
                  color: context.colors.attention,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title,
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      Text(
                        _error!.toLocalizedString(context),
                        style: context.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _AppUpdateSecondaryButton(
            onPressed: _controller.retryUpdate,
            text: context.ln.tryAgain,
          ),
        ],
      );
    }

    if (_isUpToDate) {
      return Column(
        children: [
          Text(context.ln.upToDate),
          const SizedBox(height: 16),
          _AppUpdateSecondaryButton(
            onPressed: () => _controller.checkForUpdates(),
            text: context.ln.checkForUpdates,
          ),
        ],
      );
    }

    if (_availableUpdate != null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Text(
                  context.ln.updateVersionAvailable(_availableUpdate!.version.toString()),
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  context.ln.updateConnectionWarning,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _controller.updateApplication,
            child: Text(context.ln.updateAction),
          ),
        ],
      );
    }

    return Column(
      children: [
        _AppUpdateSecondaryButton(
          onPressed: _initialLoadCompleted ? () => _controller.checkForUpdates() : null,
          text: context.ln.checkForUpdates,
        ),
      ],
    );
  }
}

class _AppUpdateDownloadProgress extends StatefulWidget {
  const _AppUpdateDownloadProgress();

  @override
  State<_AppUpdateDownloadProgress> createState() => _AppUpdateDownloadProgressState();
}

class _AppUpdateDownloadProgressState extends State<_AppUpdateDownloadProgress> {
  late AppVersionAndUpdatingScopeController _controller;
  late AvailableAppUpdate? _availableUpdate;
  late double _progress;
  late bool _canCancelDownload;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = AppVersionAndUpdatingScope.controllerOf(
      context: context,
      aspect: AppVersionAndUpdatingScopeAspect.progress,
    );
    _availableUpdate = _controller.availableUpdate;
    _progress = _controller.progress;
    _canCancelDownload = _controller.canCancelDownload;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.ln.downloadingUpdate(_availableUpdate!.version.toString()),
                style: context.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
            ],
          ),
        ),
        _AppUpdateSecondaryButton(
          onPressed: _canCancelDownload ? _controller.cancelInstallerDownload : null,
          text: context.ln.cancel,
        ),
      ],
    ),
  );
}

class _AppUpdateSecondaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;

  const _AppUpdateSecondaryButton({
    required this.onPressed,
    required this.text,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: onPressed == null ? context.colors.neutralLight : context.colors.neutralBlack),
    ),
    onPressed: onPressed,
    child: Text(text),
  );
}
