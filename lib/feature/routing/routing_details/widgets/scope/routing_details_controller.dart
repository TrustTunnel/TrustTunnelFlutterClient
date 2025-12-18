import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/data/model/routing_mode.dart';
import 'package:trusttunnel/feature/routing/routing_details/model/routing_details_data.dart';

typedef RoutingDataChangedCallback =
    void Function({
      RoutingDetailsData? data,
      bool? hasInvalidRules,
    });

abstract class RoutingDetailsScopeController {
  abstract final int? id;
  abstract final RoutingDetailsData data;

  abstract final RoutingDetailsData initialData;

  abstract final bool loading;
  abstract final bool editing;
  abstract final bool hasChanges;

  abstract final bool hasInvalidRules;
  abstract final String name;

  abstract final PresentationError? error;

  abstract final void Function() fetchProfile;
  abstract final RoutingDataChangedCallback changeData;

  abstract final void Function(VoidCallback onSaved) submit;

  abstract final void Function(VoidCallback onCleared) clearRules;

  abstract final void Function(
    RoutingMode mode,
    VoidCallback onChanged,
  )
  changeDefaultRoutingMode;
}
