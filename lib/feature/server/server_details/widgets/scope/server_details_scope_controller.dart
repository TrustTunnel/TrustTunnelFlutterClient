import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server_data.dart';
import 'package:trusttunnel/data/model/vpn_protocol.dart';

typedef DataChangedCallback =
    void Function({
      String? serverName,
      String? ipAddress,
      String? domain,
      String? username,
      String? password,
      VpnProtocol? protocol,
      String? routingProfileId,
      List<String>? dnsServers,
    });

abstract class ServerDetailsScopeController {
  abstract final ServerData data;
  abstract final List<RoutingProfile> routingProfiles;
  abstract final List<PresentationField> fieldErrors;

  abstract final String? id;

  abstract final bool loading;

  abstract final bool editing;

  abstract final bool hasChanges;

  abstract final PresentationError? error;

  abstract final void Function() fetchServer;

  abstract final DataChangedCallback changeData;

  abstract final void Function(ValueChanged<String> onSaved) submit;

  abstract final void Function(ValueChanged<String> onSaved) delete;
}
