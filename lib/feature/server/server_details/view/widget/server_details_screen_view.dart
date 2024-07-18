import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/feature/server/server_details/bloc/server_details_bloc.dart';
import 'package:vpn/feature/server/server_details/view/widget/server_details_form.dart';
import 'package:vpn/feature/server/server_details/view/widget/server_details_submit_button_section.dart';
import 'package:vpn/view/custom_app_bar.dart';
import 'package:vpn/view/progress_wrapper.dart';
import 'package:vpn/view/scaffold_wrapper.dart';

class ServerDetailsScreenView extends StatefulWidget {
  const ServerDetailsScreenView({
    super.key,
  });

  @override
  State<ServerDetailsScreenView> createState() =>
      _ServerDetailsScreenViewState();
}

class _ServerDetailsScreenViewState extends State<ServerDetailsScreenView> {
  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
        child: Scaffold(
          appBar: CustomAppBar(
            title: context.read<ServerDetailsBloc>().state.serverId == null
                ? context.ln.addServer
                : context.ln.editServer,
          ),
          body: const Column(
            children: [
              Expanded(
                child: ServerDetailsForm(),
              ),
              ServerDetailsSubmitButtonSection(),
            ],
          ),
        ),
      );
}
