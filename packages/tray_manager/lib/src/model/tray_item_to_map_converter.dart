import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

/// Converts [TrayItem] tree to Map tree for the native layer.
///
/// During conversion, generates unique IDs for buttons and collects
/// callbacks into a registry map that can be used for dispatching clicks.
class TrayItemConverter extends Converter<TrayItem, Map<String, Object?>> {
  /// Registry of button ID to callback mappings.
  final Map<String, VoidCallback> _callbacks = {};

  /// Counter for generating unique button IDs.
  int _idCounter = 0;

  /// Returns an unmodifiable view of registered callbacks.
  Map<String, VoidCallback> get callbacks => Map.unmodifiable(_callbacks);

  @override
  Map<String, Object?> convert(TrayItem input) => switch (input) {
    TraySeparator() => {
      'text': '',
      'isEnabled': true,
      'type': 'separator',
    },
    TrayStatus(:final title) => {
      'text': title,
      'isEnabled': true,
      'type': 'status',
    },
    TrayButton(
      :final title,
      :final isEnabled,
      :final isChecked,
      :final icon,
      :final onTap,
      :final children,
    ) =>
      _convertButton(
        title,
        isEnabled,
        isChecked,
        icon,
        onTap,
        children,
      ),
    _ => throw UnimplementedError(),
  };

  /// Clears all registered callbacks and resets the ID counter.
  void reset() {
    _callbacks.clear();
    _idCounter = 0;
  }

  /// Generates the next unique button ID.
  String _nextId() => 'item_${_idCounter++}';

  Map<String, Object?> _convertButton(
    String title,
    bool isEnabled,
    bool isChecked,
    TrayIcon? icon,
    VoidCallback? onTap,
    List<TrayItem> children,
  ) {
    final id = _nextId();
    if (onTap != null) {
      _callbacks[id] = onTap;
    }

    final result = <String, Object?>{
      'id': id,
      'text': title,
      'isEnabled': isEnabled,
      'type': 'button',
      'isMonochrome': icon?.isMonochrome ?? false,
      'children': children.map(convert).toList(),
    };

    if (isChecked) {
      result['isChecked'] = true;
    }

    final iconBytes = icon?.bytes;

    if (iconBytes != null) {
      result['iconPng'] = iconBytes;
    }

    return result;
  }
}
