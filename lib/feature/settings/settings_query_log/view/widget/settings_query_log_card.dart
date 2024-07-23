import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/feature/settings/settings_query_log/data/query_log_data.dart';

class SettingsQueryLogCard extends StatefulWidget {
  final QueryLogData log;

  const SettingsQueryLogCard({
    super.key,
    required this.log,
  });

  @override
  State<SettingsQueryLogCard> createState() => _SettingsQueryLogCardState();
}

class _SettingsQueryLogCardState extends State<SettingsQueryLogCard> {
  final DateFormat _formatter = DateFormat('dd.MM.yyyy HH:mm:ss');

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  _titleLine(),
                  style: context.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 3),
              Flexible(
                child: Text(
                  _detailLine(),
                  style: context.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );

  String _formatDateTime(DateTime dateTime) => _formatter.format(
        dateTime,
      );

  String _titleLine() =>
      '${_formatDateTime(widget.log.dateTime)}    ${widget.log.networkProtocol} -> ${widget.log.routingMode}';

  String _detailLine() =>
      '${widget.log.originIpAddress} -> ${widget.log.vpnServerIpAddress} (${widget.log.ipAddressDomain})';
}
