import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';

typedef ExcludedRoutesDataChangedCallback = void Function({
  List<String>? excludedRoutes,
  bool? hasInvalidRoutes,
});

abstract class ExcludedRoutesScopeController implements Listenable {
  abstract final List<String> excludedRoutes;
  abstract final List<String> initialExcludedRoutes;
  abstract final List<String> defaultExcludedRoutes;
  abstract final bool hasInvalidRoutes;
  abstract final bool hasChanges;

  abstract final bool canSave;
  abstract final bool canReset;
  abstract final bool loading;

  abstract final PresentationException? error;

  abstract final void Function() fetchExcludedRoutes;
  abstract final ExcludedRoutesDataChangedCallback changeData;
  abstract final void Function() resetToDefault;

  abstract final void Function(VoidCallback onSaved) submit;
}
