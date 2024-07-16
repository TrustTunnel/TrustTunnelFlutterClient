import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/feature/server/servers/bloc/servers_bloc.dart';
import 'package:vpn/feature/server/servers/view/widget/servers_screen_view.dart';

class ServersScreen extends StatelessWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<ServersBloc>(
        create: (context) => context.blocFactory.serversBloc()
          ..add(
            const ServersEvent.init(),
          ),
        child: const ServersScreenView(),
      );
}
