import 'dart:ui';

/// Caption controls handled by the Windows non-client input path.
enum WindowsCaptionButton { minimize, maximize, close }

/// Logical rectangles relative to the Flutter view, including the title bar.
/// Native code converts them using the HWND's current DPI. Keep interactive
/// exclusions separate from the drag area when adding controls to the bar.
class WindowsTitleBarRegions {
  final double viewWidth;
  final Rect drag;
  final Rect minimize;
  final Rect maximize;
  final Rect close;
  final List<Rect> exclusions;

  const WindowsTitleBarRegions({
    required this.viewWidth,
    required this.drag,
    required this.minimize,
    required this.maximize,
    required this.close,
    this.exclusions = const [],
  });

  Map<String, Object> toMap() => {
    'viewWidth': viewWidth,
    'drag': _rect(drag),
    'minimize': _rect(minimize),
    'maximize': _rect(maximize),
    'close': _rect(close),
    'exclusions': exclusions.map(_rect).toList(),
  };

  static List<double> _rect(Rect rect) => [
    rect.left,
    rect.top,
    rect.right,
    rect.bottom,
  ];
}

class WindowsTitleBarState {
  final bool maximized;
  final bool active;
  final WindowsCaptionButton? hovered;
  final WindowsCaptionButton? pressed;
  final bool highContrast;

  /// System caption and highlight colors, with neutral startup defaults.
  final Color captionBackgroundColor;
  final Color captionForegroundColor;
  final Color highlightColor;
  final Color highlightTextColor;
  final String fontFamily;
  final double systemTextScale;

  const WindowsTitleBarState({
    this.maximized = false,
    this.active = true,
    this.hovered,
    this.pressed,
    this.highContrast = false,
    this.captionBackgroundColor = const Color(0xffffffff),
    this.captionForegroundColor = const Color(0xff000000),
    this.highlightColor = const Color(0xff000000),
    this.highlightTextColor = const Color(0xffffffff),
    this.fontFamily = 'Segoe UI',
    this.systemTextScale = 1,
  });

  factory WindowsTitleBarState.fromMap(Map<Object?, Object?> map) =>
      WindowsTitleBarState(
        maximized: map['maximized'] as bool,
        active: map['active'] as bool,
        hovered: _button(map['hovered'] as String),
        pressed: _button(map['pressed'] as String),
        highContrast: map['highContrast'] as bool,
        captionBackgroundColor: Color(map['captionBackgroundColor'] as int),
        captionForegroundColor: Color(map['captionForegroundColor'] as int),
        highlightColor: Color(map['highlightColor'] as int),
        highlightTextColor: Color(map['highlightTextColor'] as int),
        fontFamily: map['fontFamily'] as String,
        systemTextScale: (map['textScale'] as num).toDouble(),
      );

  static WindowsCaptionButton? _button(String name) {
    for (final button in WindowsCaptionButton.values) {
      if (button.name == name) {
        return button;
      }
    }

    return null;
  }
}
