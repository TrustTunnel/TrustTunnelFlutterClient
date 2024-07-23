import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/feature/settings/settings_query_log/bloc/settings_query_log_bloc.dart';
import 'package:vpn/feature/settings/settings_query_log/view/widget/settings_query_log_screen_view.dart';

class SettingsQueryLogScreen extends StatelessWidget {
  const SettingsQueryLogScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<SettingsQueryLogBloc>(
        create: (context) => context.blocFactory.settingsQueryLogBloc()
          ..add(
            const SettingsQueryLogEvent.init(),
          ),
        child: const SettingsQueryLogScreenView(),
      );
}
