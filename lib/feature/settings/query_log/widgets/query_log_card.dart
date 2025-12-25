import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/data/model/vpn_log.dart';

class QueryLogCard extends StatelessWidget {
  final VpnLog log;

  const QueryLogCard({
    super.key,
    required this.log,
  });

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _titleLine(context),
            style: context.textTheme.bodySmall,
          ),
          const SizedBox(height: 3),
          Text(
            _ipAddressLine(),
            style: context.textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );

  String _titleLine(BuildContext context) {
    final dateTimeFormat = DateFormat.yMd('ru').add_Hms();

    return '${dateTimeFormat.format(log.timeStamp)} ${log.protocol.name.toUpperCase()} -> ${log.action.name}';
  }

  String _ipAddressLine() => '${log.source} -> ${_dstLine()}';

  String _dstLine() {
    final destination = log.destination;
    final domain = log.domain?.replaceAll('-', '‑');

    if (domain != null && destination != null) {
      return '$destination ($domain)';
    }

    return destination ?? domain ?? '(unknown)';
  }
}
