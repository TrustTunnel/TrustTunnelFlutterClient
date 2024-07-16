import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vpn/common/assets/asset_icons.dart';
import 'package:vpn/common/assets/font_families.dart';
import 'package:vpn/common/extensions/theme_extensions.dart';

class LightTheme {
  static const _primary1 = Color(0xFF67B279);
  static const _primary2 = Color(0xFF5B9F6B);
  static const _primary3 = Color(0xFF4E8C5D);
  static const _primary4 = Color(0xFFA2D0AD);
  static const _blend1 = Color(0xFFD9ECDE);
  static const _blend2 = Color(0xFFBEDFC6);
  static const _blend3 = Color(0xFFA2D0AD);
  static const _orange1 = Color(0xFFD58500);
  static const _orange2 = Color(0xFFC77901);
  static const _orange3 = Color(0xFFB76C01);
  static const _orange4 = Color(0xFFE5B460);
  static const _red1 = Color(0xFFE9653A);
  static const _red2 = Color(0xFFE75727);
  static const _red3 = Color(0xFFDC4918);
  static const _red4 = Color(0xFFEF9071);
  static const _background1 = Color(0xFFFFFFFF);
  static const _background2 = Color(0xFFF6F6F6);
  static const _background3 = Color(0xFFE4E4E4);
  static const _gray1 = Color(0xFFA4A4A4);
  static const _gray2 = Color(0xFF7F7F7F);
  static const _gray3 = Color(0xFF5B5B5B);
  static const _gray4 = Color(0xFFE4E4E4);
  static const _contrast1 = Color(0xFF3D3D3D);
  static const _contrast2 = Color(0xFF5B5B5B);
  static const _contrast3 = Color(0xFF7F7F7F);
  static const _contrast4 = Color(0xFFA4A4A4);
  static const _staticBlack1 = Color(0xFF0A0A0A);
  static const _staticBlack2 = Color(0xFF1F1F1F);
  static const _staticBlack3 = Color(0xFF3D3D3D);
  static const _staticWhite = Color(0xFFF6F6F6);
  static const _staticTransparent = Colors.transparent;

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
        ],

        // COLOR
        scaffoldBackgroundColor: _staticTransparent,
        brightness: Brightness.light,
        primaryColor: _primary1,
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
        bottomSheetTheme: _bottomSheetTheme,
        badgeTheme: _badgeThemeData,
        elevatedButtonTheme: _elevatedButtonTheme,
        filledButtonTheme: _filledButtonTheme,
        outlinedButtonTheme: _outlinedButtonThemeData,
        textButtonTheme: _textButtonThemeData,
        chipTheme: _chipThemeData,
        timePickerTheme: _timePickerThemeData,
        dialogTheme: _dialogTheme,
        menuButtonTheme: _menuButtonThemeData,
        menuBarTheme: _menuBarThemeData,
        dropdownMenuTheme: _dropdownMenuThemeData,
        menuTheme: _menuThemeData,
        popupMenuTheme: _popupMenuThemeData,
        datePickerTheme: _datePickerThemeData,
        navigationBarTheme: _navigationBarThemeData,
        appBarTheme: _appBarTheme,
        progressIndicatorTheme: _progressIndicatorThemeData,
        inputDecorationTheme: _inputDecorationTheme,
        dividerTheme: _dividerThemeData,
        navigationRailTheme: _navigationRailThemeData,
        actionIconTheme: _actionIconThemeData,
        listTileTheme: _listTileThemeData,
        cardTheme: _cardTheme,
        expansionTileTheme: _expansionTileTheme,
        buttonTheme: _buttonTheme,
      );

  late final _customColors = const CustomColors(
    primary1: _primary1,
    primary2: _primary2,
    primary3: _primary3,
    primary4: _primary4,
    blend1: _blend1,
    blend2: _blend2,
    blend3: _blend3,
    orange1: _orange1,
    orange2: _orange2,
    orange3: _orange3,
    orange4: _orange4,
    red1: _red1,
    red2: _red2,
    red3: _red3,
    red4: _red4,
    background1: _background1,
    background2: _background2,
    background3: _background3,
    gray1: _gray1,
    gray2: _gray2,
    gray3: _gray3,
    gray4: _gray4,
    contrast1: _contrast1,
    contrast2: _contrast2,
    contrast3: _contrast3,
    contrast4: _contrast4,
    staticBlack1: _staticBlack1,
    staticBlack2: _staticBlack2,
    staticBlack3: _staticBlack3,
    staticWhite: _staticWhite,
    staticTransparent: _staticTransparent,
  );

  late final _colorScheme = ColorScheme.fromSeed(
    seedColor: _primary1,
  );

  final _textTheme = const TextTheme(
    displayLarge: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _contrast1,
      fontSize: 57,
      letterSpacing: -0.25,
      height: 1.12,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    displayMedium: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _contrast1,
      fontSize: 45,
      height: 1.15,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    displaySmall: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _contrast1,
      fontSize: 36,
      height: 1.22,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    headlineLarge: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _contrast1,
      fontSize: 32,
      height: 1.25,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    headlineMedium: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _contrast1,
      fontSize: 28,
      height: 1.28,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    headlineSmall: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _contrast1,
      fontSize: 24,
      height: 1.33,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    titleLarge: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _contrast1,
      fontSize: 22,
      height: 1.27,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    titleMedium: TextStyle(
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      color: _contrast1,
      fontSize: 16,
      letterSpacing: 0.15,
      height: 1.5,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    titleSmall: TextStyle(
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      color: _contrast1,
      fontSize: 14,
      letterSpacing: 0.1,
      height: 1.42,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    labelLarge: TextStyle(
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      color: _contrast1,
      fontSize: 14,
      letterSpacing: 0.1,
      height: 1.42,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    labelMedium: TextStyle(
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      color: _contrast1,
      fontSize: 12,
      letterSpacing: 0.5,
      height: 1.33,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    labelSmall: TextStyle(
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      color: _contrast1,
      fontSize: 11,
      letterSpacing: 0.5,
      height: 1.45,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    bodyLarge: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _contrast1,
      fontSize: 16,
      letterSpacing: 0.5,
      height: 1.5,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    bodyMedium: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _contrast1,
      fontSize: 14,
      letterSpacing: 0.25,
      height: 1.42,
      fontFamily: FontFamilies.roboto,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    bodySmall: TextStyle(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      color: _contrast1,
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

  late final _checkboxThemeData = CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith(
      (states) {
        if (states.contains(WidgetState.selected) && !states.contains(WidgetState.disabled)) return _primary1;
        if (states.contains(WidgetState.selected) && states.contains(WidgetState.disabled)) return _primary4;
        return null;
      },
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(2.0),
    ),
    side: WidgetStateBorderSide.resolveWith(
      (states) {
        if (!states.contains(WidgetState.selected) && !states.contains(WidgetState.disabled)) {
          return const BorderSide(width: 2, color: _gray1);
        }
        if (!states.contains(WidgetState.selected) && states.contains(WidgetState.disabled)) {
          return const BorderSide(width: 2, color: _gray4);
        }
        return null;
      },
    ),
    overlayColor: WidgetStateProperty.resolveWith(
      (states) {
        if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return _background2;
        return null;
      },
    ),
  );

  late final _iconButtonThemeData = IconButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.disabled)) return _contrast4;
          return _contrast1;
        },
      ),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.disabled)) return _staticTransparent;
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return _background2;
          if (states.contains(WidgetState.pressed)) return _background3;
          return null;
        },
      ),
      mouseCursor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.disabled)) return SystemMouseCursors.basic;
          return null;
        },
      ),
      textStyle: WidgetStatePropertyAll(_textTheme.labelLarge),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(10)),
      iconSize: const WidgetStatePropertyAll(24),
    ),
  );

  late final _radioThemeData = RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith(
      (states) {
        if (states.contains(WidgetState.disabled)) return _contrast4;
        if (!states.contains(WidgetState.disabled) && !states.contains(WidgetState.selected)) return _contrast1;
        return _primary1;
      },
    ),
    overlayColor: WidgetStateProperty.resolveWith(
      (states) {
        if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return _background2;
        if (states.contains(WidgetState.pressed)) return _background3;
        return null;
      },
    ),
  );

  late final _floatingActionButtonThemeData = FloatingActionButtonThemeData(
    backgroundColor: _primary1,
    extendedTextStyle: _textTheme.labelLarge?.copyWith(color: _staticWhite),
    foregroundColor: _staticWhite,
    iconSize: 24,
    extendedSizeConstraints: const BoxConstraints(minHeight: 56),
    smallSizeConstraints: const BoxConstraints(minHeight: 40, minWidth: 40),
    sizeConstraints: const BoxConstraints(minHeight: 56, minWidth: 56),
    largeSizeConstraints: const BoxConstraints(minHeight: 96, minWidth: 96),
    focusColor: _primary2,
    hoverColor: _primary2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  );

  late final _switchThemeData = SwitchThemeData(
    trackColor: WidgetStateProperty.resolveWith(
      (states) {
        if (states.contains(WidgetState.disabled) && states.contains(WidgetState.selected)) return _primary4;
        if (states.contains(WidgetState.disabled) && !states.contains(WidgetState.selected)) return _background2;
        if (!states.contains(WidgetState.selected)) return _background2;
        return _primary1;
      },
    ),
    thumbColor: WidgetStateProperty.resolveWith(
      (states) {
        if (states.contains(WidgetState.selected)) return _staticWhite;
        if (states.contains(WidgetState.disabled)) return _contrast4;
        if (states.contains(WidgetState.focused) || states.contains(WidgetState.focused)) return _contrast2;
        if (states.contains(WidgetState.pressed)) return _contrast3;
        return _contrast1;
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
        if (!states.contains(WidgetState.selected)) {
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return _contrast2;
          if (states.contains(WidgetState.disabled)) return _contrast4;
          return _contrast1;
        }
        return null;
      },
    ),
  );

  late final _snackBarThemeData = SnackBarThemeData(
    backgroundColor: _staticBlack1,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
    ),
    behavior: SnackBarBehavior.floating,
    contentTextStyle: _textTheme.bodyMedium?.copyWith(color: _staticWhite),
    actionTextColor: _primary1,
    closeIconColor: _staticWhite,
  );

  late final _bottomSheetTheme = const BottomSheetThemeData(
    backgroundColor: _background1,
    modalBackgroundColor: _background1,
    surfaceTintColor: _background1,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
    ),
  );

  late final _badgeThemeData = BadgeThemeData(
    textColor: _staticWhite,
    textStyle: _textTheme.labelSmall,
    backgroundColor: _red1,
    smallSize: 6,
    largeSize: 16,
    padding: const EdgeInsets.symmetric(horizontal: 4),
  );

  late final _customFilledButtonTheme = CustomFilledButtonTheme(
    danger: FilledButtonThemeData(
      style: _filledButtonTheme.style?.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.disabled)) return _red4;
            return _red1;
          },
        ),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.pressed)) return _red3;
            if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return _red2;
            return null;
          },
        ),
      ),
    ),
    attention: FilledButtonThemeData(
      style: _filledButtonTheme.style?.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.disabled)) return _orange4;
            return _orange1;
          },
        ),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.pressed)) return _orange3;
            if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return _orange2;
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
            if (states.contains(WidgetState.disabled)) return _red4;
            return _red1;
          },
        ),
      ),
    ),
    attention: TextButtonThemeData(
      style: _textButtonThemeData.style?.copyWith(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.disabled)) return _primary4;
            return _primary1;
          },
        ),
      ),
    ),
    success: TextButtonThemeData(
      style: _textButtonThemeData.style?.copyWith(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.disabled)) return _primary4;
            return _primary1;
          },
        ),
      ),
    ),
    inlineButton: TextButtonThemeData(
      style: _textButtonThemeData.style?.copyWith(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const WidgetStatePropertyAll(Size.zero),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
        side: const WidgetStatePropertyAll(BorderSide.none),
        textStyle: WidgetStateProperty.resolveWith(
          (states) {
            final decorationColor = states.contains(WidgetState.disabled) ? _primary4 : _primary1;

            return _textTheme.bodyMedium!.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: decorationColor,
            );
          },
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.disabled)) return _primary4;
            return _primary1;
          },
        ),
      ),
    ),
    iconButton: _textButtonThemeData,
  );

  late final _elevatedButtonTheme = ElevatedButtonThemeData(style: _filledButtonTheme.style);

  late final _filledButtonTheme = FilledButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.disabled)) return _primary4;
          return _primary1;
        },
      ),
      foregroundColor: const WidgetStatePropertyAll(_staticWhite),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.pressed)) return _primary3;
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return _primary2;
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
          if (states.contains(WidgetState.disabled)) return _contrast4;
          return _contrast1;
        },
      ),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.pressed)) return _background3;
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return _background2;
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
          if (states.contains(WidgetState.disabled)) return _contrast4;
          return _contrast1;
        },
      ),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.pressed)) return _background3;
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return _background2;
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

  late final _chipThemeData = ChipThemeData(
    labelStyle: _textTheme.labelLarge,
    padding: const EdgeInsets.symmetric(
      vertical: 8,
      horizontal: 16,
    ),
    surfaceTintColor: _background1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    color: WidgetStateProperty.resolveWith(
      (states) {
        if (states.contains(WidgetState.selected)) {
          if (states.contains(WidgetState.pressed)) return _blend3;
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return _blend2;
          if (states.contains(WidgetState.disabled)) return _blend2;
          return _blend1;
        } else {
          if (states.contains(WidgetState.pressed)) return _background3;
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return _background2;
          if (states.contains(WidgetState.disabled)) return _background2;
          return _background1;
        }
      },
    ),
    backgroundColor: _background1,
    disabledColor: _background2,
    selectedColor: _blend1,
    checkmarkColor: _contrast1,
    elevation: 0,
  );

  late final _appBarTheme = AppBarTheme(
    backgroundColor: _staticTransparent,
    surfaceTintColor: _staticTransparent,
    shadowColor: _staticTransparent,
    elevation: 0.11,
    titleTextStyle: _textTheme.titleLarge,
    centerTitle: true,
  );

  late final _navigationBarThemeData = const NavigationBarThemeData(
    backgroundColor: _background2,
    indicatorColor: _blend2,
  );

  late final _popupMenuThemeData = PopupMenuThemeData(
    color: _background1,
    position: PopupMenuPosition.under,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4.0),
    ),
    surfaceTintColor: _background1,
  );

  late final _datePickerThemeData = DatePickerThemeData(
    backgroundColor: _background2,
    headerBackgroundColor: _background2,
    headerForegroundColor: _contrast1,
    surfaceTintColor: _staticTransparent,
    rangePickerSurfaceTintColor: _staticTransparent,
    headerHeadlineStyle: _textTheme.headlineLarge,
    headerHelpStyle: _textTheme.labelLarge,
    weekdayStyle: _textTheme.bodyLarge,
    dayStyle: _textTheme.bodyLarge,
    dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return _primary1;
      return _staticTransparent;
    }),
    todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return _primary1;
      return _staticTransparent;
    }),
    dayForegroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return _staticWhite;
      if (states.contains(WidgetState.disabled)) return _contrast4;

      return _contrast1;
    }),
    todayForegroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return _staticWhite;
      if (states.contains(WidgetState.disabled)) return _contrast4;

      return _contrast1;
    }),
    yearStyle: _textTheme.labelLarge,
    yearForegroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return _staticWhite;
      if (states.contains(WidgetState.disabled)) return _contrast4;

      return _contrast1;
    }),
    yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return _primary1;
      return _staticTransparent;
    }),
    inputDecorationTheme: _inputDecorationTheme.copyWith(errorMaxLines: 2),
    rangePickerBackgroundColor: _background2,
    rangePickerHeaderBackgroundColor: _background2,
    rangePickerHeaderForegroundColor: _contrast1,
    rangePickerHeaderHeadlineStyle: _textTheme.titleLarge,
    rangePickerHeaderHelpStyle: _textTheme.labelLarge,
    rangeSelectionBackgroundColor: _blend1,
    dividerColor: _gray1,
    cancelButtonStyle: _textButtonThemeData.style?.copyWith(
      textStyle: WidgetStatePropertyAll(_textTheme.labelLarge),
    ),
    confirmButtonStyle: _textButtonThemeData.style?.copyWith(
      textStyle: WidgetStatePropertyAll(_textTheme.labelLarge),
    ),
    dayOverlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return _primary2;
      return _background2;
    }),
    yearOverlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return _primary2;
      return _background2;
    }),
  );

  late final _timePickerThemeData = TimePickerThemeData(
    backgroundColor: _background2,
    cancelButtonStyle: _textButtonThemeData.style?.copyWith(
      textStyle: WidgetStatePropertyAll(_textTheme.labelLarge),
    ),
    confirmButtonStyle: _textButtonThemeData.style?.copyWith(
      textStyle: WidgetStatePropertyAll(_textTheme.labelLarge),
    ),
    hourMinuteColor: _background3,
    entryModeIconColor: _contrast1,
    dialHandColor: _primary1,
    dialTextColor: _contrast1,
    dialBackgroundColor: _background3,
    dayPeriodBorderSide: const BorderSide(color: _blend1),
    helpTextStyle: _textTheme.labelLarge,
    inputDecorationTheme: _inputDecorationTheme,
  );

  late final _dialogTheme = DialogTheme(
    backgroundColor: _background1,
    surfaceTintColor: _staticTransparent,
    titleTextStyle: _textTheme.headlineSmall,
    contentTextStyle: _textTheme.bodyMedium,
    iconColor: _contrast1,
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
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return _background2;
          if (states.contains(WidgetState.pressed)) return _background3;
          return null;
        },
      ),
    ),
  );

  late final _menuBarThemeData = const MenuBarThemeData(
    style: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(_background1),
      surfaceTintColor: WidgetStatePropertyAll(_staticTransparent),
    ),
  );

  late final _dropdownMenuThemeData = DropdownMenuThemeData(
    textStyle: _textTheme.bodyLarge,
    inputDecorationTheme: _inputDecorationTheme,
    menuStyle: const MenuStyle(
      backgroundColor: WidgetStatePropertyAll(_background1),
      surfaceTintColor: WidgetStatePropertyAll(_staticTransparent),
      visualDensity: VisualDensity.standard,
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(vertical: 8),
      ),
    ),
  );

  late final _menuThemeData = const MenuThemeData(
    style: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(_background1),
      surfaceTintColor: WidgetStatePropertyAll(_staticTransparent),
    ),
  );

  late final _progressIndicatorThemeData = const ProgressIndicatorThemeData(
    color: _primary1,
    circularTrackColor: _blend1,
    linearTrackColor: _blend1,
    linearMinHeight: 4,
  );

  late final _inputDecorationTheme = InputDecorationTheme(
    filled: true,
    disabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: _contrast4),
    ),
    errorBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: _red1),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: _contrast1, width: 3),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: _red1, width: 3),
    ),
    outlineBorder: const BorderSide(color: _contrast1),
    border: const OutlineInputBorder(
      borderSide: BorderSide(color: _contrast1),
    ),
    floatingLabelStyle: WidgetStateTextStyle.resolveWith(
      (states) {
        if (states.contains(WidgetState.disabled)) {
          return _textTheme.bodySmall!.copyWith(color: _contrast4);
        }

        if (states.contains(WidgetState.error)) {
          return _textTheme.bodySmall!.copyWith(color: _red1);
        }

        return _textTheme.bodySmall!;
      },
    ),
    labelStyle: WidgetStateTextStyle.resolveWith(
      (states) {
        if (states.contains(WidgetState.disabled)) {
          return _textTheme.bodySmall!.copyWith(color: _contrast4);
        }

        if (states.contains(WidgetState.error)) {
          return _textTheme.bodySmall!.copyWith(color: _red1);
        }

        return _textTheme.bodySmall!;
      },
    ),
    alignLabelWithHint: true,
    hoverColor: _background2,
    fillColor: _staticTransparent,
    iconColor: _contrast1,
    prefixIconColor: _contrast1,
    suffixIconColor: WidgetStateColor.resolveWith(
      (states) {
        if (states.contains(WidgetState.disabled)) {
          return _contrast4;
        }

        if (states.contains(WidgetState.error)) {
          return _red1;
        }

        return _contrast1;
      },
    ),
    errorStyle: _textTheme.bodySmall?.copyWith(color: _red1),
    hintStyle: _textTheme.bodyLarge?.copyWith(color: _contrast4),
    helperStyle: WidgetStateTextStyle.resolveWith(
      (states) {
        if (states.contains(WidgetState.disabled)) {
          return _textTheme.bodySmall!.copyWith(color: _contrast4);
        }

        return _textTheme.bodySmall!;
      },
    ),
    counterStyle: WidgetStateTextStyle.resolveWith((states) => _textTheme.bodySmall!),
    contentPadding: const EdgeInsets.only(top: 16, bottom: 16, left: 16),
    floatingLabelBehavior: FloatingLabelBehavior.always,
    focusColor: _background2,
  );

  late final _textSelectionTheme = const TextSelectionThemeData(
    cursorColor: _contrast1,
    selectionColor: _blend1,
    selectionHandleColor: _primary1,
  );

  late final _dividerThemeData = const DividerThemeData(
    color: _gray4,
    space: 1,
  );

  late final _iconThemeData = const IconThemeData(
    size: 24,
    color: _contrast1,
  );

  late final _navigationRailThemeData = NavigationRailThemeData(
    indicatorColor: _blend2,
    unselectedLabelTextStyle: _textTheme.labelMedium,
    selectedLabelTextStyle: _textTheme.labelMedium,
    backgroundColor: _background2,
  );

  late final _actionIconThemeData = ActionIconThemeData(
    backButtonIconBuilder: (context) => SvgPicture.asset(
      AssetIcons.arrowBack,
      width: 24,
      height: 24,
      colorFilter: const ColorFilter.mode(_contrast1, BlendMode.srcIn),
    ),
  );

  late final _listTileThemeData = ListTileThemeData(
    contentPadding: const EdgeInsets.all(16),
    titleTextStyle: _textTheme.titleSmall,
    subtitleTextStyle: _textTheme.bodyMedium?.copyWith(color: _gray1),
  );

  final _cardTheme = CardTheme(
    color: _background2,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12.0),
    ),
    surfaceTintColor: _background1,
  );

  late final _customDropdownMenuTheme = CustomDropdownMenuTheme(
    enabled: _dropdownMenuThemeData,
    disabled: _dropdownMenuThemeData.copyWith(
      textStyle: _dropdownMenuThemeData.textStyle?.copyWith(color: _contrast4),
    ),
  );

  final _expansionTileTheme = ExpansionTileThemeData(
    backgroundColor: _background2,
    iconColor: _contrast1,
    textColor: _contrast1,
    collapsedIconColor: _contrast1,
    collapsedTextColor: _contrast1,
    collapsedBackgroundColor: _background2,
    collapsedShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
    ),
    tilePadding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 4,
    ),
    childrenPadding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 8,
    ),
  );

  final _customFilledIconButtonTheme = CustomFilledIconButtonTheme(
    iconButton: IconButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return _primary1;
            }
            return _gray1;
          },
        ),
      ),
    ),
  );
}
