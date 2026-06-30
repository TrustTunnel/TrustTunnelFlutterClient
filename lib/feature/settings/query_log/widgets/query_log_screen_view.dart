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
  List<VpnLog> _logs = [];

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final logController = VpnScope.logsControllerOf(context);
    if (!listEquals(logController.logs, _logs)) {
      _logs = [...logController.logs];
    }
  }

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
    child: Scaffold(
      appBar: CustomAppBar(
        title: context.ln.connectionLog,
      ),
      body: QueryLogListView(
        logs: _logs,
        controller: _scrollController,
      ),
    ),
  );

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class QueryLogListView extends StatelessWidget {
  final ScrollController? controller;
  final List<VpnLog> logs;

  const QueryLogListView({
    super.key,
    this.controller,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) => ListView.separated(
    controller: controller,
    reverse: true,
    shrinkWrap: logs.length < 50,

    itemBuilder: (context, index) {
      final log = logs[index];

      return QueryLogCard(
        key: ValueKey(log.timeStamp.microsecondsSinceEpoch),
        log: log,
      );
    },
    separatorBuilder: (_, _) => const Divider(),
    itemCount: logs.length,
  );
}
