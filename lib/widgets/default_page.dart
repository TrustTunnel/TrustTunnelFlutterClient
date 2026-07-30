import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';

class DefaultPage extends StatelessWidget {
  final String title;
  final String? descriptionText;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final String imagePath;
  final Size imageSize;

  final Size? _desktopImageSize;
  final String? _desktopImagePath;

  const DefaultPage({
    super.key,
    required this.title,
    required this.imagePath,
    this.imageSize = const Size.square(270),
    this.descriptionText,
    this.buttonText,
    this.onButtonPressed,
  }) : _desktopImageSize = null,
       _desktopImagePath = null;

  const DefaultPage.responsive({
    super.key,
    required this.title,
    required this.imagePath,
    this.imageSize = const Size.square(270),
    Size desktopImageSize = const Size.square(300),
    this.descriptionText,
    this.buttonText,
    this.onButtonPressed,
    String? desktopImagePath,
  }) : _desktopImagePath = desktopImagePath ?? imagePath,
       _desktopImageSize = desktopImageSize;

  @override
  Widget build(BuildContext context) {
    final String imagePath;
    final Size imageSize;

    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.linux when _desktopImagePath != null:
        imagePath = _desktopImagePath;
      default:
        imagePath = this.imagePath;
    }

    if (context.isMobileBreakpoint) {
      imageSize = this.imageSize;
    } else {
      imageSize = _desktopImageSize ?? this.imageSize;
    }

    return Center(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  imagePath,
                  width: imageSize.width,
                  height: imageSize.height,
                  fit: BoxFit.contain,
                ),
                Padding(
                  padding: context.isMobileBreakpoint
                      ? const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 12)
                      : const EdgeInsets.only(left: 44, right: 44, top: 8, bottom: 12),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: context.textTheme.headlineMedium,
                  ),
                ),
                if (descriptionText != null)
                  Padding(
                    padding: context.isMobileBreakpoint
                        ? const EdgeInsets.only(left: 24, right: 24, bottom: 16)
                        : const EdgeInsets.only(left: 44, right: 44, bottom: 16),
                    child: Text(
                      descriptionText!,
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodyMedium,
                    ),
                  ),
                if (buttonText != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: FilledButton(
                      onPressed: onButtonPressed,
                      child: Text(buttonText!),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
