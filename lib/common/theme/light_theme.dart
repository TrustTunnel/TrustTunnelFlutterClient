import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/assets/font_families.dart';
import 'package:trusttunnel/common/extensions/theme_extensions.dart';
import 'package:trusttunnel/widgets/custom_icon.dart';

class LightTheme {
  static const _accent = Color(0xFF3972AA);
  static const _accentHover = Color(0xFF336699);
  static const _accentPressed = Color(0xFF2D5986);
  static const _accentDisabled = Color(0x664F8AC4);

  static const _accentAdditional = Color(0xFF4F8AC4);

  static const _blend = Color(0x334F8AC4);
  static const _blendHover = Color(0x4D4F8AC4);
  static const _blendPressed = Color(0x664F8AC4);
  static const _attention = Color(0xFFF08400);
  static const _attentionHover = Color(0xFFE07400);
  static const _attentionPressed = Color(0xFFC76300);
  static const _attentionDisabled = Color(0x80FFA424);
  static const _error = Color(0xFFF44725);
  static const _errorHover = Color(0xFFE7320D);
  static const _errorPressed = Color(0xFFD02C0B);
  static const _errorDisabled = Color(0x80F56447);
  static const _background = Color(0xFFFFFFFF);
  static const _backgroundHover = Color(0xFFF6F7F9);
  static const _backgroundPressed = Color(0xFFE6EAEF);

  static const _neutralBlend = Color(0x1A30353B);

  static const _backgroundAdditional = Color(0xFFF6F7F9);
  static const _backgroundElevated = Color(0xFFFFFFFF);
  static const _backgroundSystem = Color(0xFFE6EAEF);
  static const _backgroundSystemHover = Color(0xFFD1D8E0);
  static const _backgroundSystemPressed = Color(0xFFBFC8D4);
  static const _neutralLight = Color(0xFF9AA8B8);
  static const _neutralLightHover = Color(0xFF8997A9);
  static const _neutralLightPressed = Color(0xFF74869C);
  static const _neutralLightDisabled = Color(0x3330353B);
  static const _neutralDark = Color(0xFF74869C);
  static const _neutralDarkHover = Color(0xFF5C6E84);
  static const _neutralDarkPressed = Color(0xFF465567);
  static const _neutralDarkDisabled = Color(0x4D30353B);
  static const _neutralBlack = Color(0xFF333E4C);
  static const _neutralBlackHover = Color(0xFF242D38);
  static const _neutralBlackPressed = Color(0xFF1A2028);
  static const _neutralBlackDisabled = Color(0x6630353B);
  static const _specialStaticWhite = Color(0xFFFFFFFF);
  static const _specialStaticWhiteHover = Color(0xFFF6F7F9);
  static const _specialStaticWhitePressed = Color(0xFFE6EAEF);
  static const _specialStaticWhiteDisabled = Color(0x80FFFFFF);
  static const _staticTransparent = Colors.transparent;

  late final _customColors = const CustomColors(
    accent: _accent,
    accentHover: _accentHover,
    accentPressed: _accentPressed,
    accentDisabled: _accentDisabled,
    blend: _blend,
    blendHover: _blendHover,
    blendPressed: _blendPressed,
    attention: _attention,
    attentionHover: _attentionHover,
    attentionPressed: _attentionPressed,
    attentionDisabled: _attentionDisabled,
    error: _error,
    errorHover: _errorHover,
    errorPressed: _errorPressed,
    errorDisabled: _errorDisabled,
    background: _background,
    backgroundAdditional: _backgroundAdditional,
    backgroundElevated: _backgroundElevated,
    backgroundSystem: _backgroundSystem,
    backgroundSystemHover: _backgroundSystemHover,
    backgroundSystemPressed: _backgroundSystemPressed,
    neutralLight: _neutralLight,
    neutralLightHover: _neutralLightHover,
    neutralLightPressed: _neutralLightPressed,
    neutralLightDisabled: _neutralLightDisabled,
    neutralBlack: _neutralBlack,
    neutralBlackHover: _neutralBlackHover,
    neutralBlackPressed: _neutralBlackPressed,
    neutralBlackDisabled: _neutralBlackDisabled,
    neutralDark: _neutralDark,
    neutralDarkHover: _neutralDarkHover,
    neutralDarkPressed: _neutralDarkPressed,
    neutralDarkDisabled: _neutralDarkDisabled,
    specialStaticWhite: _specialStaticWhite,
    specialStaticWhiteHover: _specialStaticWhiteHover,
    specialStaticWhitePressed: _specialStaticWhitePressed,
    specialStaticWhiteDisabled: _specialStaticWhiteDisabled,
    staticTransparent: _staticTransparent,
  );

  late final _colorScheme = ColorScheme.fromSeed(
    seedColor: _accent,
  );

  late final _checkboxThemeData = CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith(
      (states) {
        if (states.contains(WidgetState.selected) && !states.contains(WidgetState.disabled)) return _accent;
        if (states.contains(WidgetState.selected) && states.contains(WidgetState.disabled)) return _accentDisabled;

        return null;
      },
    ),
    checkColor: WidgetStateProperty.all(_specialStaticWhite),
    side: WidgetStateBorderSide.resolveWith(
      (states) {
        if (!states.contains(WidgetState.selected) && !states.contains(WidgetState.disabled)) {
          return const BorderSide(width: 2, color: _neutralLight);
        }
        if (!states.contains(WidgetState.selected) && states.contains(WidgetState.disabled)) {
          return const BorderSide(width: 2, color: _neutralLightDisabled);
        }

        return null;
      },
    ),
    overlayColor: WidgetStateProperty.resolveWith(
      (states) {
        if (states.contains(WidgetState.pressed)) return _accentPressed.withValues(alpha: 0.2);

        if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return _backgroundSystem;

        return _staticTransparent;
      },
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(2.0),
    ),
  );

  late final _iconButtonThemeData = IconButtonThemeData(
    style: ButtonStyle(
      shape: const WidgetStatePropertyAll(
        CircleBorder(),
      ),
      foregroundColor: const WidgetStatePropertyAll(
        _specialStaticWhite,
      ),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.pressed) || states.contains(WidgetState.focused)) return _backgroundHover;
          if (states.contains(WidgetState.hovered)) return _backgroundPressed;

          return null;
        },
      ),
      mouseCursor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.disabled)) return SystemMouseCursors.basic;

          return null;
        },
      ),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
      iconSize: const WidgetStatePropertyAll(24),
    ),
  );

  late final _radioThemeData = RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith(
      (states) {
        if (states.contains(WidgetState.disabled)) return _neutralBlack.withValues(alpha: 0.38);
        if (states.contains(WidgetState.selected)) return _accent;

        return _neutralBlack;
      },
    ),
    overlayColor: WidgetStateProperty.resolveWith(
      (states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused) ||
            states.contains(WidgetState.pressed))
          return _backgroundSystem;

        return _staticTransparent;
      },
    ),
  );

  late final _floatingActionButtonThemeData = FloatingActionButtonThemeData(
    backgroundColor: _accent,
    extendedTextStyle: _textTheme.labelLarge?.copyWith(color: _specialStaticWhite),
    foregroundColor: _specialStaticWhite,
    iconSize: 24,
    extendedSizeConstraints: const BoxConstraints(minHeight: 56),
    smallSizeConstraints: const BoxConstraints(minHeight: 40, minWidth: 40),
    sizeConstraints: const BoxConstraints(minHeight: 56, minWidth: 56),
    largeSizeConstraints: const BoxConstraints(minHeight: 96, minWidth: 96),
    focusColor: _accentHover,
    hoverColor: _accentHover,
    splashColor: _accentPressed,
    hoverElevation: 4,
    elevation: 3,
    focusElevation: 3,
    disabledElevation: 3,
    highlightElevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  );

  late final _switchThemeData = SwitchThemeData(
    trackColor: WidgetStateProperty.resolveWith(
      (states) {
        if (!states.contains(WidgetState.disabled) && states.contains(WidgetState.pressed)) return _accentPressed;
        if (!states.contains(WidgetState.selected)) return _backgroundSystem;

        return _accent;
      },
    ),
    thumbColor: WidgetStateProperty.resolveWith(
      (states) {
        if (states.contains(WidgetState.selected)) return _specialStaticWhite;
        if (states.contains(WidgetState.disabled)) return _neutralDarkDisabled.withValues(alpha: 0.3);
        if (states.contains(WidgetState.pressed)) return _neutralDarkPressed;
        if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return _neutralDark;

        return _neutralBlack;
      },
    ),
    overlayColor: const WidgetStatePropertyAll(_staticTransparent),
    trackOutlineWidth: WidgetStateProperty.resolveWith(
      (states) {
        if (!states.contains(WidgetState.selected)) return 2;

        return 0;
      },
    ),
    trackOutlineColor: WidgetStateProperty.resolveWith(
      (states) {
        if (states.contains(WidgetState.selected)) return null;

        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused) ||
            states.contains(WidgetState.disabled))
          return _neutralDark;

        return _neutralBlack;
      },
    ),
  );

  late final _snackBarThemeData = SnackBarThemeData(
    backgroundColor: _neutralBlack,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
    ),
    behavior: SnackBarBehavior.floating,
    elevation: 3,
    contentTextStyle: _textTheme.bodyMedium?.copyWith(color: _specialStaticWhite),
    actionTextColor: _accentAdditional,

    closeIconColor: _specialStaticWhite,
  );

  late final _badgeThemeData = BadgeThemeData(
    textColor: _specialStaticWhite,
    textStyle: _textTheme.labelSmall,
    backgroundColor: _error,
    smallSize: 6,
    largeSize: 16,
    padding: const EdgeInsets.symmetric(horizontal: 4),
  );

  late final _customFilledButtonTheme = CustomFilledButtonTheme(
    danger: FilledButtonThemeData(
      style: _filledButtonTheme.style?.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.disabled)) return _error.withValues(alpha: 0.5);

            return _error;
          },
        ),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.pressed)) return _errorPressed;
            if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return _errorHover;

            return null;
          },
        ),
      ),
    ),
    attention: FilledButtonThemeData(
      style: _filledButtonTheme.style?.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.disabled)) return _attention.withValues(alpha: 0.5);

            return _attention;
          },
        ),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.pressed)) return _attentionPressed;
            if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return _attentionHover;

            return null;
          },
        ),
      ),
    ),
    iconButton: FilledButtonThemeData(
      style: _filledButtonTheme.style?.copyWith(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.only(top: 10, bottom: 10, left: 16, right: 24),
        ),
      ),
    ),
  );

  late final _customElevatedButtonTheme = CustomElevatedButtonTheme(
    iconButton: ElevatedButtonThemeData(
      style: _filledButtonTheme.style?.copyWith(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.only(top: 10, bottom: 10, left: 16, right: 24),
        ),
      ),
    ),
  );

  late final _customOutlinedButtonTheme = CustomOutlinedButtonTheme(
    iconButton: OutlinedButtonThemeData(
      style: _outlinedButtonThemeData.style?.copyWith(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.only(top: 10, bottom: 10, left: 16, right: 24),
        ),
      ),
    ),
  );

  late final _customTextButtonTheme = CustomTextButtonTheme(
    danger: TextButtonThemeData(
      style: _textButtonThemeData.style?.copyWith(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.disabled)) return _errorDisabled.withValues(alpha: 0.5);

            return _error;
          },
        ),
      ),
    ),
    attention: TextButtonThemeData(
      style: _textButtonThemeData.style?.copyWith(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.disabled)) return _attentionDisabled.withValues(alpha: 0.5);

            return _attention;
          },
        ),
      ),
    ),
    success: TextButtonThemeData(
      style: _textButtonThemeData.style?.copyWith(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.disabled)) return _accentDisabled.withValues(alpha: 0.5);

            return _accent;
          },
        ),
      ),
    ),
    iconButton: _textButtonThemeData,
  );

  late final _elevatedButtonTheme = ElevatedButtonThemeData(
    style: _filledButtonTheme.style,
  );

  late final _filledButtonTheme = FilledButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.disabled)) return _accentDisabled.withValues(alpha: 0.4);

          return _accent;
        },
      ),
      foregroundColor: const WidgetStatePropertyAll(_specialStaticWhite),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.pressed)) return _accentPressed;
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return _accentHover;

          return null;
        },
      ),
      textStyle: WidgetStatePropertyAll(_textTheme.labelLarge),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      ),
      iconSize: const WidgetStatePropertyAll(18),
      minimumSize: WidgetStatePropertyAll(
        Size(_buttonTheme.minWidth, _buttonTheme.height),
      ),
      visualDensity: VisualDensity.standard,
    ),
  );

  late final _outlinedButtonThemeData = OutlinedButtonThemeData(
    style: _filledButtonTheme.style?.copyWith(
      backgroundColor: const WidgetStatePropertyAll(_staticTransparent),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.disabled)) return _neutralLight;

          return _neutralBlack;
        },
      ),
      shape: WidgetStateProperty.resolveWith(
        (states) {
          final Color borderColor;

          if (states.contains(WidgetState.disabled)) {
            borderColor = _neutralLight;
          } else {
            borderColor = _neutralBlack;
          }

          return StadiumBorder(
            side: BorderSide(
              color: borderColor,
            ),
          );
        },
      ),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.pressed)) return _backgroundPressed;
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return _backgroundHover;

          return null;
        },
      ),
    ),
  );

  late final _textButtonThemeData = TextButtonThemeData(
    style: _filledButtonTheme.style?.copyWith(
      backgroundColor: const WidgetStatePropertyAll(_staticTransparent),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.disabled)) return _neutralLight;

          return _neutralBlack;
        },
      ),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.pressed)) return _backgroundPressed;
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return _backgroundHover;

          return _staticTransparent;
        },
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      textStyle: WidgetStatePropertyAll(
        _textTheme.labelLarge,
      ),
    ),
  );

  late final _appBarTheme = AppBarTheme(
    backgroundColor: _staticTransparent,
    surfaceTintColor: _staticTransparent,
    shadowColor: _staticTransparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: _textTheme.titleLarge,
    centerTitle: true,
    foregroundColor: _neutralBlack,
  );

  late final _navigationBarThemeData = const NavigationBarThemeData(
    backgroundColor: _backgroundSystem,
    indicatorColor: _blendHover,
  );

  late final _popupMenuThemeData = PopupMenuThemeData(
    color: _background,
    position: PopupMenuPosition.under,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4.0),
    ),
    surfaceTintColor: _background,

    elevation: 2,
    textStyle: _textTheme.bodyLarge?.copyWith(
      color: _neutralBlack,
    ),
  );

  late final _menuButtonThemeData = MenuButtonThemeData(
    style: _textButtonThemeData.style?.copyWith(
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      ),
      textStyle: WidgetStatePropertyAll(_textTheme.bodyLarge),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.disabled)) return _staticTransparent;
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused) ||
              states.contains(WidgetState.selected))
            return _backgroundSystemHover;
          if (states.contains(WidgetState.pressed)) return _backgroundSystemPressed;

          return null;
        },
      ),
    ),
  );

  late final _menuBarThemeData = const MenuBarThemeData(
    style: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(_background),
      surfaceTintColor: WidgetStatePropertyAll(_staticTransparent),
    ),
  );

  late final _dropdownMenuThemeData = DropdownMenuThemeData(
    textStyle: _textTheme.bodyLarge,
    inputDecorationTheme: _inputDecorationTheme,
    menuStyle: const MenuStyle(
      backgroundColor: WidgetStatePropertyAll(_background),
      surfaceTintColor: WidgetStatePropertyAll(_staticTransparent),
      visualDensity: VisualDensity.standard,
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(vertical: 8),
      ),
    ),
  );

  late final _menuThemeData = const MenuThemeData(
    style: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(_background),
      surfaceTintColor: WidgetStatePropertyAll(_staticTransparent),
    ),
  );

  late final _progressIndicatorThemeData = ProgressIndicatorThemeData(
    color: _accent,
    circularTrackColor: _blend.withValues(alpha: 0.2),
    linearTrackColor: _blend.withValues(alpha: 0.2),
    linearMinHeight: 4,
  );

  late final _inputDecorationTheme = InputDecorationTheme(
    filled: true,
    disabledBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: _neutralDarkDisabled.withValues(
          alpha: 0.3,
        ),
      ),
    ),
    errorBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: _error),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: _neutralBlack, width: 3),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: _error, width: 3),
    ),
    outlineBorder: const BorderSide(color: _neutralBlack),
    border: const OutlineInputBorder(
      borderSide: BorderSide(color: _neutralBlack),
    ),
    floatingLabelStyle: WidgetStateTextStyle.resolveWith(
      (states) {
        if (states.contains(WidgetState.disabled)) {
          return _textTheme.bodySmall!.copyWith(color: _neutralBlackDisabled.withValues(alpha: 0.4));
        }

        if (states.contains(WidgetState.error)) {
          return _textTheme.bodySmall!.copyWith(color: _error);
        }

        return _textTheme.bodySmall!;
      },
    ),
    labelStyle: WidgetStateTextStyle.resolveWith(
      (states) {
        if (states.contains(WidgetState.disabled)) {
          return _textTheme.bodySmall!.copyWith(color: _neutralBlackDisabled.withValues(alpha: 0.3));
        }

        if (states.contains(WidgetState.error)) {
          return _textTheme.bodySmall!.copyWith(color: _error);
        }

        return _textTheme.bodySmall!;
      },
    ),
    alignLabelWithHint: true,
    hoverColor: _backgroundSystem,
    fillColor: _staticTransparent,
    iconColor: _neutralBlack,
    prefixIconColor: WidgetStateColor.resolveWith(
      (states) {
        if (states.contains(WidgetState.disabled)) {
          return _neutralBlackDisabled;
        }

        return _neutralBlack;
      },
    ),
    suffixIconColor: WidgetStateColor.resolveWith(
      (states) {
        if (states.contains(WidgetState.disabled)) {
          return _neutralBlackDisabled;
        }

        if (states.contains(WidgetState.error)) {
          return _error;
        }

        return _neutralBlack;
      },
    ),
    errorStyle: _textTheme.bodySmall?.copyWith(color: _error),
    hintStyle: WidgetStateTextStyle.resolveWith(
      (states) {
        final Color textColor;
        if (states.contains(WidgetState.disabled)) {
          textColor = _neutralDarkDisabled.withValues(alpha: 0.4);
        } else {
          textColor = _neutralDark;
        }

        return _textTheme.bodyLarge!.copyWith(color: textColor);
      },
    ),
    helperStyle: WidgetStateTextStyle.resolveWith(
      (states) {
        if (states.contains(WidgetState.disabled)) {
          return _textTheme.bodySmall!.copyWith(color: _neutralBlackDisabled.withValues(alpha: 0.3));
        }

        if (states.contains(WidgetState.error)) {
          return _textTheme.bodySmall!.copyWith(color: _error);
        }

        return _textTheme.bodySmall!;
      },
    ),
    counterStyle: WidgetStateTextStyle.resolveWith((states) => _textTheme.bodySmall!),
    contentPadding: const EdgeInsets.only(top: 16, bottom: 16, left: 16),
    floatingLabelBehavior: FloatingLabelBehavior.always,
    focusColor: _staticTransparent,
  );

  late final _textSelectionTheme = TextSelectionThemeData(
    cursorColor: WidgetStateColor.resolveWith(
      (states) {
        if (states.contains(WidgetState.error)) {
          return _error;
        }

        return _neutralBlack;
      },
    ),
    selectionColor: _blend,
    selectionHandleColor: _accent,
  );

  late final _dividerThemeData = const DividerThemeData(
    color: _neutralBlend,
    space: 1,
  );

  late final _iconThemeData = const IconThemeData(
    size: 24,
    color: _neutralBlack,
  );

  late final _navigationRailThemeData = NavigationRailThemeData(
    indicatorColor: _blend.withValues(alpha: 0.2),
    unselectedLabelTextStyle: _textTheme.labelMedium,
    selectedLabelTextStyle: _textTheme.labelMedium,
    backgroundColor: _backgroundSystem,
  );

  late final _actionIconThemeData = ActionIconThemeData(
    closeButtonIconBuilder: (context) => CustomIcon.medium(
      icon: AssetIcons.close,
      color: _neutralBlack,
    ),
    backButtonIconBuilder: (context) => CustomIcon.medium(
      icon: AssetIcons.arrowBack,
      color: _neutralBlack,
    ),
  );

  late final _listTileThemeData = ListTileThemeData(
    contentPadding: const EdgeInsets.all(16),
    titleTextStyle: _textTheme.titleSmall,
    subtitleTextStyle: _textTheme.bodyMedium?.copyWith(color: _neutralLight),
  );

  late final _customDropdownMenuTheme = CustomDropdownMenuTheme(
    enabled: _dropdownMenuThemeData,
    disabled: _dropdownMenuThemeData.copyWith(
      textStyle: _dropdownMenuThemeData.textStyle?.copyWith(
        color: _neutralBlackDisabled.withValues(alpha: 0.4),
      ),
    ),
  );

  late final _tabBarTheme = TabBarThemeData(
    labelColor: _accent,
    unselectedLabelColor: _neutralBlack,
    indicatorColor: _accent,
    labelPadding: const EdgeInsets.symmetric(
      vertical: 12,
      horizontal: 16,
    ),
    labelStyle: _textTheme.titleSmall,
  );

  late final _dialogTheme = DialogThemeData(
    backgroundColor: _background,
    surfaceTintColor: _staticTransparent,
    titleTextStyle: _textTheme.headlineSmall,
    contentTextStyle: _textTheme.bodyMedium,
    iconColor: _accent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(28.0),
      ),
    ),
  );

  final _textTheme = const TextTheme(
    displayLarge: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _neutralBlack,
      fontSize: 57,
      letterSpacing: -0.25,
      height: 1.12,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    displayMedium: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _neutralBlack,
      fontSize: 45,
      height: 1.15,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    displaySmall: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _neutralBlack,
      fontSize: 36,
      height: 1.22,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    headlineLarge: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _neutralBlack,
      fontSize: 32,
      height: 1.25,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    headlineMedium: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _neutralBlack,
      fontSize: 28,
      height: 1.28,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    headlineSmall: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _neutralBlack,
      fontSize: 24,
      height: 1.33,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    titleLarge: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _neutralBlack,
      fontSize: 22,
      height: 1.27,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    titleMedium: TextStyle(
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      color: _neutralBlack,
      fontSize: 16,
      letterSpacing: 0.15,
      height: 1.5,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    titleSmall: TextStyle(
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      color: _neutralBlack,
      fontSize: 14,
      letterSpacing: 0.1,
      height: 1.42,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    labelLarge: TextStyle(
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      color: _neutralBlack,
      fontSize: 14,
      letterSpacing: 0.1,
      height: 1.42,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    labelMedium: TextStyle(
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      color: _neutralBlack,
      fontSize: 12,
      letterSpacing: 0.5,
      height: 1.33,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    labelSmall: TextStyle(
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      color: _neutralBlack,
      fontSize: 11,
      letterSpacing: 0.5,
      height: 1.45,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    bodyLarge: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _neutralBlack,
      fontSize: 16,
      letterSpacing: 0.5,
      height: 1.5,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    bodyMedium: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _neutralBlack,
      fontSize: 14,
      letterSpacing: 0.25,
      height: 1.42,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    bodySmall: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _neutralBlack,
      fontSize: 12,
      letterSpacing: 0.4,
      height: 1.33,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
  );

  final _buttonTheme = const ButtonThemeData(
    minWidth: 70,
    height: 40,
  );

  final _customFilledIconButtonTheme = CustomFilledIconButtonTheme(
    iconButton: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(_specialStaticWhite),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return _accent;
            }

            return _neutralDark;
          },
        ),
      ),
    ),
    iconButtonInProgress: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(_specialStaticWhite),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return _accent;
            }

            return _neutralDark;
          },
        ),
      ),
    ),
  );

  final _customMissSpelledTextTheme = const CustomMissSpelledTextTheme(
    missSpelledStyle: TextStyle(
      decorationColor: _error,
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.wavy,
      decorationThickness: 2,
    ),
  );

  ThemeData get data => ThemeData(
    // GENERAL CONFIGURATION
    useMaterial3: true,
    extensions: [
      _customColors,
      _customFilledButtonTheme,
      _customElevatedButtonTheme,
      _customOutlinedButtonTheme,
      _customTextButtonTheme,
      _customDropdownMenuTheme,
      _customFilledIconButtonTheme,
      _customMissSpelledTextTheme,
    ],

    // COLOR
    scaffoldBackgroundColor: _background,
    brightness: Brightness.light,
    primaryColor: _accent,
    colorScheme: _colorScheme,
    hoverColor: _staticTransparent,
    focusColor: _staticTransparent,

    // TYPOGRAPHY & ICONOGRAPHY
    textTheme: _textTheme,
    fontFamily: FontFamilies.roboto,
    iconTheme: _iconThemeData,
    textSelectionTheme: _textSelectionTheme,

    // COMPONENT THEMES
    checkboxTheme: _checkboxThemeData,
    iconButtonTheme: _iconButtonThemeData,
    radioTheme: _radioThemeData,
    floatingActionButtonTheme: _floatingActionButtonThemeData,
    switchTheme: _switchThemeData,
    snackBarTheme: _snackBarThemeData,
    badgeTheme: _badgeThemeData,
    elevatedButtonTheme: _elevatedButtonTheme,
    filledButtonTheme: _filledButtonTheme,
    outlinedButtonTheme: _outlinedButtonThemeData,
    textButtonTheme: _textButtonThemeData,
    dialogTheme: _dialogTheme,
    menuButtonTheme: _menuButtonThemeData,
    menuBarTheme: _menuBarThemeData,
    dropdownMenuTheme: _dropdownMenuThemeData,
    menuTheme: _menuThemeData,
    popupMenuTheme: _popupMenuThemeData,
    navigationBarTheme: _navigationBarThemeData,
    appBarTheme: _appBarTheme,
    progressIndicatorTheme: _progressIndicatorThemeData,
    inputDecorationTheme: _inputDecorationTheme,
    dividerTheme: _dividerThemeData,
    navigationRailTheme: _navigationRailThemeData,
    actionIconTheme: _actionIconThemeData,
    listTileTheme: _listTileThemeData,
    buttonTheme: _buttonTheme,
    tabBarTheme: _tabBarTheme,
  );
}
