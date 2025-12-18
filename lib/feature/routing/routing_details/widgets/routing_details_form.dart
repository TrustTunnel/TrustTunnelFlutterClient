import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/extensions/locale_enum_extension.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/data/model/routing_mode.dart';
import 'package:trusttunnel/feature/routing/routing_details/domain/service/routing_spell_check_service.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/scope/routing_details_aspect.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/scope/routing_details_scope.dart';
import 'package:trusttunnel/widgets/inputs/custom_text_field.dart';

class RoutingDetailsForm extends StatefulWidget {
  const RoutingDetailsForm({super.key});

  @override
  State<RoutingDetailsForm> createState() => _RoutingDetailsFormState();
}

class _RoutingDetailsFormState extends State<RoutingDetailsForm> {
  bool _bypassValid = true;
  bool _vpnValid = true;

  static const _vpnFieldKey = ValueKey('vpn_rules');
  static const _bypassFieldKey = ValueKey('bypass_rules');

  late final SpellCheckService _bypassSpellCheckService;
  late final SpellCheckService _vpnSpellCheckService;

  late List<String> _bypassRules;
  late List<String> _vpnRules;

  @override
  void initState() {
    super.initState();

    _bypassSpellCheckService = RoutingSpellCheckService(
      onChecked: (spellValid) => _onDataChanged(
        context,
        RoutingMode.bypass,
        spellValid: spellValid,
      ),
    );
    _vpnSpellCheckService = RoutingSpellCheckService(
      onChecked: (spellValid) => _onDataChanged(
        context,
        RoutingMode.vpn,
        spellValid: spellValid,
      ),
    );

    final controller = RoutingDetailsScope.controllerOf(context, listen: false);

    _bypassRules = controller.data.bypassRules;
    _vpnRules = controller.data.vpnRules;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final controller = RoutingDetailsScope.controllerOf(
      context,
      aspect: RoutingDetailsScopeAspect.data,
    );

    _bypassRules = controller.data.bypassRules;
    _vpnRules = controller.data.vpnRules;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16.0),
    child: context.isMobileBreakpoint
        ? TabBarView(
            children: [
              _bypassRulesTextField(context, _bypassRules),
              _vpnRulesTextField(context, _vpnRules),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: _bypassRulesTextField(context, _bypassRules, showLabel: true),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: _vpnRulesTextField(context, _vpnRules, showLabel: true),
              ),
            ],
          ),
  );

  CustomTextField _vpnRulesTextField(
    BuildContext context,
    List<String> vpnRules, {
    bool showLabel = false,
  }) => CustomTextField(
    key: _vpnFieldKey,
    label: showLabel ? RoutingMode.vpn.localized(context) : null,
    value: vpnRules.join('\n'),
    autofocus: true,
    hint: context.ln.enterRulesHint,
    spellCheckService: _vpnSpellCheckService,
    minLines: 40,
    maxLines: 40,
    showClearButton: false,
    onChanged: (vpnRules) => _onDataChanged(
      context,
      RoutingMode.vpn,
      vpnRules: vpnRules.split('\n').map((r) => r.trim()).where((r) => r.isNotEmpty).toList(),
    ),
  );

  CustomTextField _bypassRulesTextField(
    BuildContext context,
    List<String> bypassRules, {
    bool showLabel = false,
  }) => CustomTextField(
    key: _bypassFieldKey,
    label: showLabel ? RoutingMode.bypass.localized(context) : null,
    value: bypassRules.join('\n'),
    autofocus: true,
    hint: context.ln.enterRulesHint,
    maxLines: 40,
    spellCheckService: _bypassSpellCheckService,
    showClearButton: false,
    onChanged: (bypassRules) => _onDataChanged(
      context,
      RoutingMode.bypass,
      bypassRules: bypassRules.split('\n').map((r) => r.trim()).where((r) => r.isNotEmpty).toList(),
    ),
  );

  void _onDataChanged(
    BuildContext context,
    RoutingMode mode, {
    List<String>? vpnRules,
    List<String>? bypassRules,
    bool? spellValid,
  }) {
    if (mode == RoutingMode.bypass) {
      _bypassValid = spellValid ?? (_bypassValid || bypassRules?.isEmpty == true);
    }

    if (mode == RoutingMode.vpn) {
      _vpnValid = spellValid ?? (_vpnValid || vpnRules?.isEmpty == true);
    }
    final actualController = RoutingDetailsScope.controllerOf(context, listen: false);

    actualController.changeData(
      data: actualController.data.copyWith(
        vpnRules: vpnRules ?? actualController.data.vpnRules,
        bypassRules: bypassRules ?? actualController.data.bypassRules,
      ),
      hasInvalidRules: !_bypassValid || !_vpnValid,
    );
  }
}
