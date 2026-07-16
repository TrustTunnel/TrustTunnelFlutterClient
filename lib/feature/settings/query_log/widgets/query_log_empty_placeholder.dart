import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/assets_images.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';

class QueryLogEmptyPlaceholder extends StatelessWidget {
  const QueryLogEmptyPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final Size imageSize = context.isMobileBreakpoint ? const Size(270, 270) : const Size(400, 300);

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: ConstrainedBox(
              constraints: context.isMobileBreakpoint ? const BoxConstraints() : const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    context.isMobileBreakpoint ? AssetImages.connectionLogMobile : AssetImages.connectionLogDesktop,
                    width: imageSize.width,
                    height: imageSize.height,
                    fit: BoxFit.contain,
                  ),
                  Padding(
                    padding: context.isMobileBreakpoint
                        ? const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 12)
                        : const EdgeInsets.only(left: 44, right: 44, top: 8, bottom: 12),
                    child: Text(
                      context.ln.connectionLogEmptyTitle,
                      textAlign: TextAlign.center,
                      style: context.textTheme.headlineMedium,
                    ),
                  ),
                  Padding(
                    padding: context.isMobileBreakpoint
                        ? const EdgeInsets.only(left: 24, right: 24, bottom: 16)
                        : const EdgeInsets.only(left: 44, right: 44, bottom: 16),
                    child: Text(
                      context.ln.connectionLogEmptyDescription,
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
