import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/widgets/buttons/custom_icon_button.dart';

class CustomSnackBar extends SnackBar {
  final bool _showCloseIcon;
  final List<Widget> _trailingActions;

  const CustomSnackBar({
    super.key,
    required super.content,
    super.action,
    super.backgroundColor,
    super.behavior,
    super.duration,
    super.elevation,
    super.margin,
    super.shape,
    this._trailingActions = const [],
    this._showCloseIcon = false,
  });

  @override
  bool get showCloseIcon => false;

  @override
  EdgeInsetsGeometry? get padding => EdgeInsets.zero;

  @override
  Widget get content => Padding(
    padding: const EdgeInsets.only(
      left: 16,
      right: 16,
      bottom: 16,
    ),
    child: Builder(
      builder: (context) {
        final snackBarTheme = context.theme.snackBarTheme;
        final content = Padding(
          padding: EdgeInsets.only(
            left: 16,
            top: 14,
            right: _showCloseIcon || _trailingActions.isNotEmpty ? 0 : 16,
            bottom: 14,
          ),
          child: super.content,
        );

        return Material(
          shape: snackBarTheme.shape,
          color: snackBarTheme.backgroundColor,
          elevation: snackBarTheme.elevation ?? 0,
          textStyle: snackBarTheme.contentTextStyle,
          shadowColor: context.theme.shadowColor,
          child: Row(
            children: [
              Expanded(
                child: content,
              ),
              if (_trailingActions.isNotEmpty)
                Theme(
                  data: _getActionTheme(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _trailingActions,
                  ),
                ),
              if (_showCloseIcon)
                Theme(
                  data: _getActionTheme(context),
                  child: CustomIconButton(
                    icon: AssetIcons.close,
                    color: snackBarTheme.closeIconColor,
                    onPressed: () =>
                        ScaffoldMessenger.of(
                          context,
                        ).hideCurrentSnackBar(
                          reason: SnackBarClosedReason.dismiss,
                        ),
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );

  @override
  double? get elevation => 0;

  ThemeData _getActionTheme(BuildContext context) => context.theme.copyWith(
    hoverColor: context.colors.transparent,
    splashColor: context.colors.transparent,
    disabledColor: context.colors.transparent,
    focusColor: context.colors.transparent,
    highlightColor: context.colors.transparent,
    buttonTheme: context.theme.buttonTheme.copyWith(
      hoverColor: context.colors.transparent,
      splashColor: context.colors.transparent,
      focusColor: context.colors.transparent,
      highlightColor: context.colors.transparent,
    ),
    // TODO: Fix hover color
    // Konstantin Gorynin <k.gorynin@adguard.com>, 15 October 2025
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(
          context.colors.transparent,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(
          context.colors.transparent,
        ),
      ),
    ),
  );
}
