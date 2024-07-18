import 'package:flutter/material.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/data/model/server.dart';
import 'package:vpn/feature/server/server_details/view/server_details_screen.dart';
import 'package:vpn/feature/server/servers/view/widget/servers_card_connection_button.dart';

class ServersCard extends StatelessWidget {
  final Server server;

  const ServersCard({
    super.key,
    required this.server,
  });

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          children: [
            Flexible(
              fit: FlexFit.tight,
              child: InkWell(
                onTap: () => _pushServerDetailsScreen(
                  context,
                  server: server,
                ),
                child: Ink(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          server.name,
                          style: context.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          server.ipAddress,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colors.gray1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: VerticalDivider(
                color: context.theme.dividerTheme.color,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ServersCardConnectionButton(
                // TODO use real connection info
                isActive: true,
                server: server,
              ),
            ),
          ],
        ),
      );

  void _pushServerDetailsScreen(
    BuildContext context, {
    required Server server,
  }) =>
      context.push(
        ServerDetailsScreen(serverId: server.id),
      );
}
