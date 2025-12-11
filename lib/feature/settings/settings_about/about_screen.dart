import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vpn/common/assets/assets_images.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/view/custom_app_bar.dart';
import 'package:vpn/view/default_page.dart';
import 'package:vpn/view/scaffold_wrapper.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
    child: Scaffold(
      appBar: CustomAppBar(
        title: context.ln.about,
      ),
      body: FutureBuilder<String>(
        future: _getPackageVersion(),
        builder: (context, snapshot) => DefaultPage(
          title: context.ln.vpnOss,
          descriptionText: snapshot.data,
          imagePath: AssetImages.about,
          imageSize: const Size.square(248),
          alignment: Alignment.center,
        ),
      ),
    ),
  );

  Future<String> _getPackageVersion() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();

    return 'V${packageInfo.version}';
  }
}
