import 'package:flutter/material.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/feature/server/servers/view/widget/servers_card_connection_button.dart';

class ServersCard extends StatelessWidget {
  final Object server;

  const ServersCard({
    super.key,
    required this.server,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Flexible(
                fit: FlexFit.tight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TODO use real server data
                    Text(
                      'Server name 1',
                      style: context.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '192.168.31.75',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colors.gray1,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                child: VerticalDivider(
                  color: context.theme.dividerTheme.color,
                ),
              ),
              ServersCardConnectionButton(
                // TODO use real connection info
                isActive: true,
                server: server,
              ),
            ],
          ),
        ),
      );
}
