import 'dart:ui';

import 'package:flutter/material.dart';

class CustomColors extends ThemeExtension<CustomColors> {
  final Color accent;
  final Color accentHover;
  final Color accentPressed;
  final Color accentDisabled;

  final Color blend;
  final Color blendHover;
  final Color blendPressed;

  final Color attention;
  final Color attentionHover;
  final Color attentionPressed;
  final Color attentionDisabled;

  final Color error;
  final Color errorHover;
  final Color errorPressed;
  final Color errorDisabled;

  final Color background;
  final Color backgroundAdditional;
  final Color backgroundElevated;

  final Color backgroundSystem;
  final Color backgroundSystemHover;
  final Color backgroundSystemPressed;

  final Color neutralLight;
  final Color neutralLightHover;
  final Color neutralLightPressed;

  final Color neutralLightDisabled;
  final Color neutralDark;
  final Color neutralDarkHover;
  final Color neutralDarkPressed;

  final Color neutralBlack;
  final Color neutralDarkDisabled;
  final Color neutralBlackHover;
  final Color neutralBlackPressed;

  final Color neutralBlackDisabled;
  final Color specialStaticWhite;
  final Color specialStaticWhiteHover;
  final Color specialStaticWhitePressed;
  final Color specialStaticWhiteDisabled;

  final Color staticTransparent;

  const CustomColors({
    required this.accent,
    required this.accentHover,
    required this.accentPressed,
    required this.accentDisabled,
    required this.blend,
    required this.blendHover,
    required this.blendPressed,
    required this.attention,
    required this.attentionHover,
    required this.attentionPressed,
    required this.attentionDisabled,
    required this.error,
    required this.errorHover,
    required this.errorPressed,
    required this.errorDisabled,
    required this.background,
    required this.backgroundAdditional,
    required this.backgroundElevated,
    required this.backgroundSystem,
    required this.backgroundSystemHover,
    required this.backgroundSystemPressed,
    required this.neutralLight,
    required this.neutralLightHover,
    required this.neutralLightPressed,
    required this.neutralLightDisabled,
    required this.neutralDark,
    required this.neutralDarkHover,
    required this.neutralDarkPressed,
    required this.neutralDarkDisabled,
    required this.neutralBlack,
    required this.neutralBlackHover,
    required this.neutralBlackPressed,
    required this.neutralBlackDisabled,
    required this.specialStaticWhite,
    required this.specialStaticWhiteHover,
    required this.specialStaticWhitePressed,
    required this.specialStaticWhiteDisabled,
    required this.staticTransparent,
  });

  @override
  CustomColors copyWith({
    Color? accent,
    Color? accentHover,
    Color? accentPressed,
    Color? accentDisabled,
    Color? blend,
    Color? blendHover,
    Color? blendPressed,
    Color? attention,
    Color? attentionHover,
    Color? attentionPressed,
    Color? attentionDisabled,
    Color? error,
    Color? errorHover,
    Color? errorPressed,
    Color? errorDisabled,
    Color? background,
    Color? backgroundAdditional,
    Color? backgroundElevated,
    Color? backgroundSystem,
    Color? backgroundSystemHover,
    Color? backgroundSystemPressed,
    Color? neutralLight,
    Color? neutralLightHover,
    Color? neutralLightPressed,
    Color? neutralLightDisabled,
    Color? neutralDark,
    Color? neutralDarkHover,
    Color? neutralDarkPressed,
    Color? neutralDarkDisabled,
    Color? neutralBlack,
    Color? neutralBlackHover,
    Color? neutralBlackPressed,
    Color? neutralBlackDisabled,
    Color? specialStaticWhite,
    Color? specialStaticWhiteHover,
    Color? specialStaticWhitePressed,
    Color? specialStaticWhiteDisabled,
    Color? staticTransparent,
  }) => CustomColors(
    accent: accent ?? this.accent,
    accentHover: accentHover ?? this.accentHover,
    accentPressed: accentPressed ?? this.accentPressed,
    accentDisabled: accentDisabled ?? this.accentDisabled,
    blend: blend ?? this.blend,
    blendHover: blendHover ?? this.blendHover,
    blendPressed: blendPressed ?? this.blendPressed,
    attention: attention ?? this.attention,
    attentionHover: attentionHover ?? this.attentionHover,
    attentionPressed: attentionPressed ?? this.attentionPressed,
    attentionDisabled: attentionDisabled ?? this.attentionDisabled,
    error: error ?? this.error,
    errorHover: errorHover ?? this.errorHover,
    errorPressed: errorPressed ?? this.errorPressed,
    errorDisabled: errorDisabled ?? this.errorDisabled,
    background: background ?? this.background,
    backgroundAdditional: backgroundAdditional ?? this.backgroundAdditional,
    backgroundElevated: backgroundElevated ?? this.backgroundElevated,
    backgroundSystem: backgroundSystem ?? this.backgroundSystem,
    backgroundSystemHover: backgroundSystemHover ?? this.backgroundSystemHover,
    backgroundSystemPressed: backgroundSystemPressed ?? this.backgroundSystemPressed,
    neutralLight: neutralLight ?? this.neutralLight,
    neutralLightHover: neutralLightHover ?? this.neutralLightHover,
    neutralLightPressed: neutralLightPressed ?? this.neutralLightPressed,
    neutralLightDisabled: neutralLightDisabled ?? this.neutralLightDisabled,
    neutralDark: neutralDark ?? this.neutralDark,
    neutralDarkHover: neutralDarkHover ?? this.neutralDarkHover,
    neutralDarkPressed: neutralDarkPressed ?? this.neutralDarkPressed,
    neutralDarkDisabled: neutralDarkDisabled ?? this.neutralDarkDisabled,
    neutralBlack: neutralBlack ?? this.neutralBlack,
    neutralBlackHover: neutralBlackHover ?? this.neutralBlackHover,
    neutralBlackPressed: neutralBlackPressed ?? this.neutralBlackPressed,
    neutralBlackDisabled: neutralBlackDisabled ?? this.neutralBlackDisabled,
    specialStaticWhite: specialStaticWhite ?? this.specialStaticWhite,
    specialStaticWhiteHover: specialStaticWhiteHover ?? this.specialStaticWhiteHover,
    specialStaticWhitePressed: specialStaticWhitePressed ?? this.specialStaticWhitePressed,
    specialStaticWhiteDisabled: specialStaticWhiteDisabled ?? this.specialStaticWhiteDisabled,
    staticTransparent: staticTransparent ?? this.staticTransparent,
  );

  @override
  ThemeExtension<CustomColors> lerp(
    covariant ThemeExtension<CustomColors>? other,
    double t,
  ) {
    if (other is! CustomColors) return this;

    return CustomColors(
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentPressed: Color.lerp(accentPressed, other.accentPressed, t)!,
      accentDisabled: Color.lerp(accentDisabled, other.accentDisabled, t)!,
      blend: Color.lerp(blend, other.blend, t)!,
      blendHover: Color.lerp(blendHover, other.blendHover, t)!,
      blendPressed: Color.lerp(blendPressed, other.blendPressed, t)!,
      attention: Color.lerp(attention, other.attention, t)!,
      attentionHover: Color.lerp(attentionHover, other.attentionHover, t)!,
      attentionPressed: Color.lerp(attentionPressed, other.attentionPressed, t)!,
      attentionDisabled: Color.lerp(attentionDisabled, other.attentionDisabled, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorHover: Color.lerp(errorHover, other.errorHover, t)!,
      errorPressed: Color.lerp(errorPressed, other.errorPressed, t)!,
      errorDisabled: Color.lerp(errorDisabled, other.errorDisabled, t)!,
      background: Color.lerp(background, other.background, t)!,
      backgroundAdditional: Color.lerp(backgroundAdditional, other.backgroundAdditional, t)!,
      backgroundElevated: Color.lerp(backgroundElevated, other.backgroundElevated, t)!,
      backgroundSystem: Color.lerp(backgroundSystem, other.backgroundSystem, t)!,
      backgroundSystemHover: Color.lerp(backgroundSystemHover, other.backgroundSystemHover, t)!,
      backgroundSystemPressed: Color.lerp(backgroundSystemPressed, other.backgroundSystemPressed, t)!,
      neutralLight: Color.lerp(neutralLight, other.neutralLight, t)!,
      neutralLightHover: Color.lerp(neutralLightHover, other.neutralLightHover, t)!,
      neutralLightPressed: Color.lerp(neutralLightPressed, other.neutralLightPressed, t)!,
      neutralLightDisabled: Color.lerp(neutralLightDisabled, other.neutralLightDisabled, t)!,
      neutralDark: Color.lerp(neutralDark, other.neutralDark, t)!,
      neutralDarkHover: Color.lerp(neutralDarkHover, other.neutralDarkHover, t)!,
      neutralDarkPressed: Color.lerp(neutralDarkPressed, other.neutralDarkPressed, t)!,
      neutralDarkDisabled: Color.lerp(neutralDarkDisabled, other.neutralDarkDisabled, t)!,
      neutralBlack: Color.lerp(neutralBlack, other.neutralBlack, t)!,
      neutralBlackHover: Color.lerp(neutralBlackHover, other.neutralBlackHover, t)!,
      neutralBlackPressed: Color.lerp(neutralBlackPressed, other.neutralBlackPressed, t)!,
      neutralBlackDisabled: Color.lerp(neutralBlackDisabled, other.neutralBlackDisabled, t)!,
      specialStaticWhite: Color.lerp(specialStaticWhite, other.specialStaticWhite, t)!,
      specialStaticWhiteHover: Color.lerp(
        specialStaticWhiteHover,
        other.specialStaticWhiteHover,
        t,
      )!,
      specialStaticWhitePressed: Color.lerp(
        specialStaticWhitePressed,
        other.specialStaticWhitePressed,
        t,
      )!,
      specialStaticWhiteDisabled: Color.lerp(
        specialStaticWhiteDisabled,
        other.specialStaticWhiteDisabled,
        t,
      )!,
      staticTransparent: Color.lerp(staticTransparent, other.staticTransparent, t)!,
    );
  }
}

class CustomFilledButtonTheme extends ThemeExtension<CustomFilledButtonTheme> {
  final FilledButtonThemeData danger;
  final FilledButtonThemeData attention;
  final FilledButtonThemeData iconButton;

  const CustomFilledButtonTheme({
    required this.danger,
    required this.attention,
    required this.iconButton,
  });

  @override
  ThemeExtension<CustomFilledButtonTheme> copyWith({
    FilledButtonThemeData? danger,
    FilledButtonThemeData? attention,
    FilledButtonThemeData? iconButton,
  }) => CustomFilledButtonTheme(
    danger: danger ?? this.danger,
    attention: attention ?? this.attention,
    iconButton: attention ?? this.iconButton,
  );

  @override
  ThemeExtension<CustomFilledButtonTheme> lerp(
    covariant ThemeExtension<CustomFilledButtonTheme>? other,
    double t,
  ) {
    if (other is! CustomFilledButtonTheme) {
      return this;
    }

    return CustomFilledButtonTheme(
      danger: FilledButtonThemeData.lerp(danger, other.danger, t)!,
      attention: FilledButtonThemeData.lerp(attention, other.attention, t)!,
      iconButton: FilledButtonThemeData.lerp(iconButton, other.iconButton, t)!,
    );
  }
}

class CustomElevatedButtonTheme extends ThemeExtension<CustomElevatedButtonTheme> {
  final ElevatedButtonThemeData iconButton;

  const CustomElevatedButtonTheme({required this.iconButton});

  @override
  ThemeExtension<CustomElevatedButtonTheme> copyWith({
    ElevatedButtonThemeData? iconButton,
  }) => CustomElevatedButtonTheme(
    iconButton: iconButton ?? this.iconButton,
  );

  @override
  ThemeExtension<CustomElevatedButtonTheme> lerp(
    covariant ThemeExtension<CustomElevatedButtonTheme>? other,
    double t,
  ) {
    if (other is! CustomElevatedButtonTheme) {
      return this;
    }

    return CustomElevatedButtonTheme(
      iconButton: other.iconButton,
    );
  }
}

class CustomOutlinedButtonTheme extends ThemeExtension<CustomOutlinedButtonTheme> {
  final OutlinedButtonThemeData iconButton;

  const CustomOutlinedButtonTheme({required this.iconButton});

  @override
  ThemeExtension<CustomOutlinedButtonTheme> copyWith({
    OutlinedButtonThemeData? iconButton,
  }) => CustomOutlinedButtonTheme(
    iconButton: iconButton ?? this.iconButton,
  );

  @override
  ThemeExtension<CustomOutlinedButtonTheme> lerp(
    covariant ThemeExtension<CustomOutlinedButtonTheme>? other,
    double t,
  ) {
    if (other is! CustomOutlinedButtonTheme) {
      return this;
    }

    return CustomOutlinedButtonTheme(
      iconButton: other.iconButton,
    );
  }
}

class CustomTextButtonTheme extends ThemeExtension<CustomTextButtonTheme> {
  final TextButtonThemeData danger;
  final TextButtonThemeData attention;
  final TextButtonThemeData success;
  final TextButtonThemeData iconButton;

  const CustomTextButtonTheme({
    required this.danger,
    required this.attention,
    required this.success,
    required this.iconButton,
  });

  @override
  ThemeExtension<CustomTextButtonTheme> copyWith({
    TextButtonThemeData? danger,
    TextButtonThemeData? attention,
    TextButtonThemeData? success,
    TextButtonThemeData? iconButton,
  }) => CustomTextButtonTheme(
    danger: danger ?? this.danger,
    attention: attention ?? this.attention,
    success: success ?? this.success,
    iconButton: iconButton ?? this.iconButton,
  );

  @override
  ThemeExtension<CustomTextButtonTheme> lerp(
    covariant ThemeExtension<CustomTextButtonTheme>? other,
    double t,
  ) {
    if (other is! CustomTextButtonTheme) {
      return this;
    }

    return CustomTextButtonTheme(
      danger: TextButtonThemeData.lerp(danger, other.danger, t)!,
      attention: TextButtonThemeData.lerp(attention, other.attention, t)!,
      success: TextButtonThemeData.lerp(success, other.success, t)!,
      iconButton: TextButtonThemeData.lerp(iconButton, other.iconButton, t)!,
    );
  }
}

class CustomDropdownMenuTheme extends ThemeExtension<CustomDropdownMenuTheme> {
  final DropdownMenuThemeData enabled;
  final DropdownMenuThemeData disabled;

  const CustomDropdownMenuTheme({
    required this.enabled,
    required this.disabled,
  });

  @override
  ThemeExtension<CustomDropdownMenuTheme> copyWith({
    DropdownMenuThemeData? enabled,
    DropdownMenuThemeData? disabled,
  }) => CustomDropdownMenuTheme(
    enabled: enabled ?? this.enabled,
    disabled: disabled ?? this.disabled,
  );

  @override
  ThemeExtension<CustomDropdownMenuTheme> lerp(
    covariant ThemeExtension<CustomDropdownMenuTheme>? other,
    double t,
  ) {
    if (other is! CustomDropdownMenuTheme) {
      return this;
    }

    return CustomDropdownMenuTheme(
      enabled: DropdownMenuThemeData.lerp(enabled, other.enabled, t),
      disabled: DropdownMenuThemeData.lerp(disabled, other.disabled, t),
    );
  }
}

class CustomFilledIconButtonTheme extends ThemeExtension<CustomFilledIconButtonTheme> {
  final IconButtonThemeData iconButton;
  final IconButtonThemeData iconButtonInProgress;

  const CustomFilledIconButtonTheme({
    required this.iconButton,
    required this.iconButtonInProgress,
  });

  @override
  ThemeExtension<CustomFilledIconButtonTheme> copyWith({
    IconButtonThemeData? iconButton,
    IconButtonThemeData? iconButtonInProgress,
  }) => CustomFilledIconButtonTheme(
    iconButton: iconButton ?? this.iconButton,
    iconButtonInProgress: iconButtonInProgress ?? this.iconButtonInProgress,
  );

  @override
  ThemeExtension<CustomFilledIconButtonTheme> lerp(
    covariant ThemeExtension<CustomFilledIconButtonTheme>? other,
    double t,
  ) {
    if (other is! CustomFilledIconButtonTheme) {
      return this;
    }

    return CustomFilledIconButtonTheme(
      iconButton: IconButtonThemeData.lerp(iconButton, other.iconButton, t)!,
      iconButtonInProgress: IconButtonThemeData.lerp(iconButtonInProgress, other.iconButtonInProgress, t)!,
    );
  }
}

class CustomMissSpelledTextTheme extends ThemeExtension<CustomMissSpelledTextTheme> {
  final TextStyle missSpelledStyle;

  const CustomMissSpelledTextTheme({
    required this.missSpelledStyle,
  });

  @override
  ThemeExtension<CustomMissSpelledTextTheme> copyWith({TextStyle? missSpelledStyle}) => CustomMissSpelledTextTheme(
    missSpelledStyle: missSpelledStyle ?? this.missSpelledStyle,
  );

  @override
  ThemeExtension<CustomMissSpelledTextTheme> lerp(
    covariant ThemeExtension<CustomMissSpelledTextTheme>? other,
    double t,
  ) {
    if (other is! CustomMissSpelledTextTheme) {
      return this;
    }

    return CustomMissSpelledTextTheme(
      missSpelledStyle: TextStyle.lerp(missSpelledStyle, other.missSpelledStyle, t)!,
    );
  }

  TextStyle apply(TextStyle style) => style.merge(missSpelledStyle);
}

class CustomDialogTheme extends ThemeExtension<CustomDialogTheme> {
  final double widthS;
  final double widthL;

  const CustomDialogTheme({
    required this.widthS,
    required this.widthL,
  });

  @override
  ThemeExtension<CustomDialogTheme> copyWith({
    double? widthS,
    double? widthL,
  }) => CustomDialogTheme(
    widthS: widthS ?? this.widthS,
    widthL: widthL ?? this.widthL,
  );

  @override
  ThemeExtension<CustomDialogTheme> lerp(
    covariant ThemeExtension<CustomDialogTheme>? other,
    double t,
  ) {
    if (other is! CustomDialogTheme) {
      return this;
    }

    return CustomDialogTheme(
      widthS: lerpDouble(widthS, other.widthS, t)!,
      widthL: lerpDouble(widthL, other.widthL, t)!,
    );
  }
}
