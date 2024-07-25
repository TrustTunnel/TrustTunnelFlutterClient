import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/feature/settings/query_log/bloc/query_log_bloc.dart';
import 'package:vpn/feature/settings/query_log/view/widget/query_log_screen_view.dart';

class QueryLogScreen extends StatelessWidget {
  const QueryLogScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<QueryLogBloc>(
        create: (context) => context.blocFactory.queryLogBloc()
          ..add(
            const QueryLogEvent.init(),
          ),
        child: const QueryLogScreenView(),
      );
}
