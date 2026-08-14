import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/assets_images.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/widgets/default_page.dart';

class QueryLogEmptyPlaceholder extends StatelessWidget {
  const QueryLogEmptyPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => DefaultPage.responsive(
    title: context.ln.connectionLogEmptyTitle,
    descriptionText: context.ln.connectionLogEmptyDescription,
    imagePath: AssetImages.connectionLogMobile,
    desktopImagePath: AssetImages.connectionLogDesktop,
  );
}
