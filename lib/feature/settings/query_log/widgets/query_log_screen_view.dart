import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/data/model/vpn_log.dart';
import 'package:trusttunnel/feature/settings/query_log/widgets/query_log_card.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class QueryLogScreenView extends StatefulWidget {
  const QueryLogScreenView({super.key});

  @override
  State<QueryLogScreenView> createState() => _QueryLogScreenViewState();
}

class _QueryLogScreenViewState extends State<QueryLogScreenView> {
  List<VpnLog> logs = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final logController = VpnScope.logsControllerOf(context);
    if (!listEquals(logController.logs, logs)) {
      logs = [...logController.logs];
    }
  }

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
    child: Scaffold(
      appBar: CustomAppBar(title: context.ln.queryLog),
      body: ListView.separated(
        itemBuilder: (context, index) {
          final log = logs[logs.length - (index + 1)];

          return QueryLogCard(
            key: ValueKey(log.timeStamp.microsecondsSinceEpoch),
            log: log,
          );
        },
        separatorBuilder: (_, __) => const Divider(),
        itemCount: logs.length,
      ),
    ),
  );
}
