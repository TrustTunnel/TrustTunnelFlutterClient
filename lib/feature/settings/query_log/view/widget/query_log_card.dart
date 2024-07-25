import 'package:flutter/material.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/extensions/enum_extensions.dart';
import 'package:vpn_plugin/platform_api.g.dart';

class QueryLogCard extends StatelessWidget {
  final VpnRequest log;

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
                _titleLine(),
                style: context.textTheme.bodySmall,
              ),
              const SizedBox(height: 3),
              Text(
                _ipAddressLine(),
                style: context.textTheme.bodySmall,
              ),
              if (log.domain != null) ...[
                const SizedBox(height: 3),
                Text(
                  _domainLine()!,
                  style: context.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      );

  String _titleLine() => '${log.time}    ${log.protocol.stringValue} -> ${log.decision.stringValue}';

  String _ipAddressLine() {
    String source = log.sourceIpAddress;
    if (log.sourcePort != null) {
      source += ':${log.sourcePort!}';
    }

    String destination = log.destinationIpAddress;
    if (log.destinationPort != null) {
      destination += ':${log.destinationPort!}';
    }

    return '$source -> $destination';
  }

  String? _domainLine() => '(${log.domain})';
}
