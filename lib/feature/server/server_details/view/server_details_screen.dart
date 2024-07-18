import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/feature/server/server_details/bloc/server_details_bloc.dart';
import 'package:vpn/feature/server/server_details/view/widget/server_details_screen_view.dart';

class ServerDetailsScreen extends StatelessWidget {
  final int? serverId;

  const ServerDetailsScreen({super.key, this.serverId});

  @override
  Widget build(BuildContext context) => BlocProvider<ServerDetailsBloc>(
        create: (context) => context.blocFactory.serverDetailsBloc(
          serverId: serverId,
        )..add(const ServerDetailsEvent.init()),
        child: const ServerDetailsScreenView(),
      );
}
