import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';

class DefaultPage extends StatelessWidget {
  final String title;
  final String? descriptionText;
  final Widget? description;
  final Widget? button;
  final String? buttonText;
  final String? imagePath;
  final Size imageSize;
  final AlignmentGeometry? alignment;
  final VoidCallback? onButtonPressed;

  const DefaultPage({
    super.key,
    required this.title,
    this.descriptionText,
    this.description,
    required this.imagePath,
    required this.imageSize,
    this.alignment,
    this.buttonText,
    this.onButtonPressed,
    this.button,
  });

  @override
  Widget build(BuildContext context) {
    final button = onButtonPressed != null && buttonText != null
        ? Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: context.isMobileBreakpoint ? 16 : 32),
            child: FilledButton(
              style: context.theme.filledButtonTheme.style?.copyWith(
                minimumSize: WidgetStateProperty.all(
                  const Size(
                    double.infinity,
                    40,
                  ),
                ),
              ),
              onPressed: onButtonPressed,
              child: Text(buttonText!),
            ),
          )
        : this.button;

    return Align(
      alignment: alignment != null
          ? alignment!
          : context.isMobileBreakpoint
          ? Alignment.topCenter
          : Alignment.center,
      child: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.isMobileBreakpoint ? double.infinity : 426),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (imagePath != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Image.asset(
                          imagePath!,
                          width: imageSize.width,
                          height: imageSize.height,
                          fit: BoxFit.fill,
                          alignment: Alignment.bottomLeft,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: context.textTheme.headlineMedium,
                          ),
                          if (descriptionText != null || description != null) ...[
                            const SizedBox(
                              height: 12,
                            ),
                            if (description != null)
                              description!
                            else if (descriptionText != null)
                              Text(
                                descriptionText!,
                                textAlign: TextAlign.center,
                                style: context.textTheme.bodyMedium,
                              ),
                          ],
                          const SizedBox(
                            height: 16,
                          ),
                        ],
                      ),
                    ),
                    if (!context.isMobileBreakpoint && button != null) button,
                  ],
                ),
              ),
              if (context.isMobileBreakpoint && button != null) button,
            ],
          ),
        ),
      ),
    );
  }
}
