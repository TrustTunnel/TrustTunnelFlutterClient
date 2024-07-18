import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/feature/server/server_details/bloc/server_details_bloc.dart';

class ServerDetailsSubmitButtonSection extends StatelessWidget {
  const ServerDetailsSubmitButtonSection({
    super.key,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: context.isMobileBreakpoint
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.end,
        children: [
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () => _addServer(context),
              child: Text(
                context.read<ServerDetailsBloc>().state.serverId == null
                    ? context.ln.add
                    : context.ln.save,
              ),
            ),
          ),
        ],
      );

  void _addServer(BuildContext context) =>
      context.read<ServerDetailsBloc>().add(
            const ServerDetailsEvent.addServer(),
          );
}
