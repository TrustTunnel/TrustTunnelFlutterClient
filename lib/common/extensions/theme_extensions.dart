import 'package:flutter/material.dart';

class CustomColors extends ThemeExtension<CustomColors> {
  final Color primary1;
  final Color primary2;
  final Color primary3;
  final Color primary4;
  final Color blend1;
  final Color blend2;
  final Color blend3;
  final Color orange1;
  final Color orange2;
  final Color orange3;
  final Color orange4;
  final Color red1;
  final Color red2;
  final Color red3;
  final Color red4;
  final Color background1;
  final Color background2;
  final Color background3;
  final Color gray1;
  final Color gray2;
  final Color gray3;
  final Color gray4;
  final Color contrast1;
  final Color contrast2;
  final Color contrast3;
  final Color contrast4;
  final Color staticBlack1;
  final Color staticBlack2;
  final Color staticBlack3;
  final Color staticWhite;
  final Color staticTransparent;

  const CustomColors({
    required this.primary1,
    required this.primary2,
    required this.primary3,
    required this.primary4,
    required this.blend1,
    required this.blend2,
    required this.blend3,
    required this.orange1,
    required this.orange2,
    required this.orange3,
    required this.orange4,
    required this.red1,
    required this.red2,
    required this.red3,
    required this.red4,
    required this.background1,
    required this.background2,
    required this.background3,
    required this.gray1,
    required this.gray2,
    required this.gray3,
    required this.gray4,
    required this.contrast1,
    required this.contrast2,
    required this.contrast3,
    required this.contrast4,
    required this.staticBlack1,
    required this.staticBlack2,
    required this.staticBlack3,
    required this.staticWhite,
    required this.staticTransparent,
  });

  @override
  CustomColors copyWith({
    Color? primary1,
    Color? primary2,
    Color? primary3,
    Color? primary4,
    Color? blend1,
    Color? blend2,
    Color? blend3,
    Color? orange1,
    Color? orange2,
    Color? orange3,
    Color? orange4,
    Color? red1,
    Color? red2,
    Color? red3,
    Color? red4,
    Color? background1,
    Color? background2,
    Color? background3,
    Color? gray1,
    Color? gray2,
    Color? gray3,
    Color? gray4,
    Color? contrast1,
    Color? contrast2,
    Color? contrast3,
    Color? contrast4,
    Color? staticBlack1,
    Color? staticBlack2,
    Color? staticBlack3,
    Color? staticWhite,
    Color? staticTransparent,
  }) =>
      CustomColors(
        primary1: primary1 ?? this.primary1,
        primary2: primary2 ?? this.primary2,
        primary3: primary3 ?? this.primary3,
        primary4: primary4 ?? this.primary4,
        blend1: blend1 ?? this.blend1,
        blend2: blend2 ?? this.blend2,
        blend3: blend3 ?? this.blend3,
        orange1: orange1 ?? this.orange1,
        orange2: orange2 ?? this.orange2,
        orange3: orange3 ?? this.orange3,
        orange4: orange4 ?? this.orange4,
        red1: red1 ?? this.red1,
        red2: red2 ?? this.red2,
        red3: red3 ?? this.red3,
        red4: red4 ?? this.red4,
        background1: background1 ?? this.background1,
        background2: background2 ?? this.background2,
        background3: background3 ?? this.background3,
        gray1: gray1 ?? this.gray1,
        gray2: gray2 ?? this.gray2,
        gray3: gray3 ?? this.gray3,
        gray4: gray4 ?? this.gray4,
        contrast1: contrast1 ?? this.contrast1,
        contrast2: contrast2 ?? this.contrast2,
        contrast3: contrast3 ?? this.contrast3,
        contrast4: contrast4 ?? this.contrast4,
        staticBlack1: staticBlack1 ?? this.staticBlack1,
        staticBlack2: staticBlack2 ?? this.staticBlack2,
        staticBlack3: staticBlack3 ?? this.staticBlack3,
        staticWhite: staticWhite ?? this.staticWhite,
        staticTransparent: staticTransparent ?? this.staticTransparent,
      );

  @override
  ThemeExtension<CustomColors> lerp(covariant ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) {
      return this;
    }

    return CustomColors(
      primary1: Color.lerp(primary1, other.primary1, t)!,
      primary2: Color.lerp(primary2, other.primary2, t)!,
      primary3: Color.lerp(primary3, other.primary3, t)!,
      primary4: Color.lerp(primary4, other.primary4, t)!,
      blend1: Color.lerp(blend1, other.blend1, t)!,
      blend2: Color.lerp(blend2, other.blend2, t)!,
      blend3: Color.lerp(blend3, other.blend3, t)!,
      orange1: Color.lerp(orange1, other.orange1, t)!,
      orange2: Color.lerp(orange2, other.orange2, t)!,
      orange3: Color.lerp(orange3, other.orange3, t)!,
      orange4: Color.lerp(orange4, other.orange4, t)!,
      red1: Color.lerp(red1, other.red1, t)!,
      red2: Color.lerp(red2, other.red2, t)!,
      red3: Color.lerp(red3, other.red3, t)!,
      red4: Color.lerp(red4, other.red4, t)!,
      background1: Color.lerp(background1, other.background1, t)!,
      background2: Color.lerp(background2, other.background2, t)!,
      background3: Color.lerp(background3, other.background3, t)!,
      gray1: Color.lerp(gray1, other.gray1, t)!,
      gray2: Color.lerp(gray2, other.gray2, t)!,
      gray3: Color.lerp(gray3, other.gray3, t)!,
      gray4: Color.lerp(gray4, other.gray4, t)!,
      contrast1: Color.lerp(contrast1, other.contrast1, t)!,
      contrast2: Color.lerp(contrast2, other.contrast2, t)!,
      contrast3: Color.lerp(contrast3, other.contrast3, t)!,
      contrast4: Color.lerp(contrast4, other.contrast4, t)!,
      staticBlack1: Color.lerp(staticBlack1, other.staticBlack1, t)!,
      staticBlack2: Color.lerp(staticBlack2, other.staticBlack2, t)!,
      staticBlack3: Color.lerp(staticBlack3, other.staticBlack3, t)!,
      staticWhite: Color.lerp(staticWhite, other.staticWhite, t)!,
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
  }) =>
      CustomFilledButtonTheme(
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
  }) =>
      CustomElevatedButtonTheme(
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
  }) =>
      CustomOutlinedButtonTheme(
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
  final TextButtonThemeData inlineButton;

  const CustomTextButtonTheme({
    required this.danger,
    required this.attention,
    required this.success,
    required this.iconButton,
    required this.inlineButton,
  });

  @override
  ThemeExtension<CustomTextButtonTheme> copyWith({
    TextButtonThemeData? danger,
    TextButtonThemeData? attention,
    TextButtonThemeData? success,
    TextButtonThemeData? iconButton,
    TextButtonThemeData? inlineButton,
  }) =>
      CustomTextButtonTheme(
        danger: danger ?? this.danger,
        attention: attention ?? this.attention,
        success: success ?? this.success,
        iconButton: iconButton ?? this.iconButton,
        inlineButton: inlineButton ?? this.inlineButton,
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
      inlineButton: TextButtonThemeData.lerp(inlineButton, other.inlineButton, t)!,
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
  }) =>
      CustomDropdownMenuTheme(
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

class CustomFilledIconButtonTheme
    extends ThemeExtension<CustomFilledIconButtonTheme> {
  final IconButtonThemeData iconButton;

  const CustomFilledIconButtonTheme({
    required this.iconButton,
  });

  @override
  ThemeExtension<CustomFilledIconButtonTheme> copyWith({
    IconButtonThemeData? iconButton,
  }) =>
      CustomFilledIconButtonTheme(
        iconButton: iconButton ?? this.iconButton,
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
    );
  }
}
