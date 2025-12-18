import 'dart:ui';

import 'package:trusttunnel/common/error/model/presentation_error.dart';

typedef ExcludedRoutesDataChangedCallback =
    void Function({
      List<String>? excludedRoutes,
      bool? hasInvalidRoutes,
    });

abstract class ExcludedRoutesScopeController {
  abstract final List<String> excludedRoutes;
  abstract final List<String> initialExcludedRoutes;
  abstract final bool hasInvalidRoutes;
  abstract final bool hasChanges;

  abstract final bool canSave;
  abstract final bool loading;

  abstract final PresentationError? error;

  abstract final void Function() fetchExcludedRoutes;
  abstract final ExcludedRoutesDataChangedCallback changeData;

  abstract final void Function(VoidCallback onSaved) submit;
}
