import 'package:flutter/material.dart';
import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';

abstract class RoutingScopeController {
  abstract final List<RoutingProfile> routingList;
  abstract final List<PresentationField> fieldErrors;
  abstract final PresentationError? error;
  abstract final bool loading;

  abstract final void Function() fetchProfiles;
  abstract final void Function({
    required int id,
    required String name,
    required VoidCallback onSaved,
  })
  changeName;

  abstract final void Function(int routingProfileId, VoidCallback onDeleted) deleteProfile;

  abstract final void Function() pickProfileToChangeName;
}
