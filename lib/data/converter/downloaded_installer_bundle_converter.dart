import 'dart:convert';

import 'package:trusttunnel/data/converter/available_app_update_converter.dart';
import 'package:trusttunnel/data/model/downloaded_installer_bundle_data.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/downloaded_installer_bundle.dart';

final class DownloadedInstallerBundleEncoder
    extends Converter<DownloadedInstallerBundle, DownloadedInstallerBundleData> {
  const DownloadedInstallerBundleEncoder();

  @override
  DownloadedInstallerBundleData convert(DownloadedInstallerBundle value) => DownloadedInstallerBundleData(
    update: const AvailableAppUpdateEncoder().convert(value.update),
    path: value.path,
  );
}

final class DownloadedInstallerBundleDecoder
    extends Converter<DownloadedInstallerBundleData, DownloadedInstallerBundle> {
  const DownloadedInstallerBundleDecoder();

  @override
  DownloadedInstallerBundle convert(DownloadedInstallerBundleData value) => DownloadedInstallerBundle(
    update: const AvailableAppUpdateDecoder().convert(value.update),
    path: value.path,
  );
}
