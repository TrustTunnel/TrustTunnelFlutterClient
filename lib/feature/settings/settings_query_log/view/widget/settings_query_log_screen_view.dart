import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/feature/settings/settings_query_log/bloc/settings_query_log_bloc.dart';
import 'package:vpn/feature/settings/settings_query_log/view/widget/settings_query_log_card.dart';
import 'package:vpn/view/custom_app_bar.dart';
import 'package:vpn/view/scaffold_wrapper.dart';

class SettingsQueryLogScreenView extends StatelessWidget {
  const SettingsQueryLogScreenView({super.key});

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
        child: Scaffold(
          appBar: CustomAppBar(title: context.ln.queryLog),
          body: BlocBuilder<SettingsQueryLogBloc, SettingsQueryLogState>(
            builder: (context, state) => ListView.separated(
              itemBuilder: (context, index) => SettingsQueryLogCard(
                log: state.logs[index],
              ),
              separatorBuilder: (_, __) => const Divider(),
              itemCount: state.logs.length,
            ),
          ),
        ),
      );
}
