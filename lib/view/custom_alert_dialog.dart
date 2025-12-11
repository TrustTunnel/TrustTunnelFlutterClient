import 'package:flutter/material.dart';
import 'package:vpn/common/assets/asset_icons.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/extensions/theme_extensions.dart';
import 'package:vpn/view/custom_icon.dart';

const _titlePadding = EdgeInsets.fromLTRB(24, 24, 24, 16);

const _contentPadding = EdgeInsets.symmetric(
  horizontal: 24,
);

const _actionsPadding = EdgeInsets.fromLTRB(8, 24, 24, 24);

const _buttonPadding = EdgeInsets.symmetric(horizontal: 8);

const _buttonsVerticalSpacing = 8.0;

const _scrollable = false;
const _showCloseButton = false;

class CustomAlertDialog extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final double? height;
  final bool scrollable;
  final EdgeInsets titlePadding;
  final EdgeInsets contentPadding;
  final EdgeInsets actionsPadding;
  final EdgeInsets buttonPadding;
  final Widget? content;
  final List<Widget> Function(double spacing)? actionsBuilder;
  final bool showCloseButton;
  final Widget? closeIconVariant;
  final VoidCallback? onClose;
  final TextAlign? titleAlign;
  final MainAxisAlignment actionsAlignment;

  /// if true then [CustomDialogTheme.widthL] will be used, otherwise [CustomDialogTheme.widthS]
  final bool isWide;

  final bool divideActions;

  final bool divideTitle;

  const CustomAlertDialog({
    super.key,
    required this.title,
    this.height,
    this.scrollable = _scrollable,
    this.titlePadding = _titlePadding,
    this.contentPadding = _contentPadding,
    this.actionsPadding = _actionsPadding,
    this.buttonPadding = _buttonPadding,
    this.content,
    this.actionsBuilder,
    this.showCloseButton = _showCloseButton,
    this.onClose,
    this.closeIconVariant,
    this.isWide = false,
    this.divideActions = false,
    this.divideTitle = false,
    this.titleAlign,
    this.actionsAlignment = MainAxisAlignment.end,
  }) : titleWidget = null,
       assert(height != null ? height >= 0 : true);

  const CustomAlertDialog.customTitle({
    super.key,
    required Widget title,
    this.height,
    this.scrollable = _scrollable,
    this.titlePadding = _titlePadding,
    this.contentPadding = _contentPadding,
    this.actionsPadding = _actionsPadding,
    this.buttonPadding = _buttonPadding,
    this.content,
    this.actionsBuilder,
    this.showCloseButton = _showCloseButton,
    this.onClose,
    this.closeIconVariant,
    this.isWide = false,
    this.divideActions = false,
    this.divideTitle = false,
    this.titleAlign,
    this.actionsAlignment = MainAxisAlignment.end,
  }) : title = null,
       titleWidget = title,
       assert(height != null ? height >= 0 : true);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final actionsSpacing = 8.0;

      final dialogTitle = title != null || titleWidget != null
          ? Padding(
              padding: titlePadding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  title == null
                      ? Expanded(child: titleWidget!)
                      : Expanded(
                          child: Text(
                            title!,
                            style: context.theme.dialogTheme.titleTextStyle,
                            textAlign: titleAlign,
                          ),
                        ),
                  if (showCloseButton || closeIconVariant != null)
                    const SizedBox(
                      width: 16,
                    ),
                  if (showCloseButton && closeIconVariant == null)
                    InkWell(
                      onTap: onClose ?? Navigator.of(context).pop,
                      child: CustomIcon.medium(
                        icon: AssetIcons.close,
                        color: context.colors.neutralDark,
                      ),
                    ),
                  if (closeIconVariant != null) closeIconVariant!,
                ],
              ),
            )
          : null;

      final dialogContent = Padding(
        padding: contentPadding,
        child: content,
      );

      final actionsLayout = OverflowBar(
        alignment: actionsAlignment,
        spacing: actionsSpacing,
        overflowSpacing: _buttonsVerticalSpacing,
        children: actionsBuilder?.call(actionsSpacing) ?? [],
      );

      final dialogActions = Padding(
        padding: actionsPadding,
        child: actionsLayout,
      );

      final List<Widget> columnChildren = [
        if (dialogTitle != null) ...[
          dialogTitle,
          if (divideTitle) const Divider(),
        ],
        if (content != null)
          Flexible(
            child: scrollable
                ? ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: <Widget>[
                      if (content != null) dialogContent,
                    ],
                  )
                : dialogContent,
          ),
        if (actionsBuilder != null) ...[
          if (content == null)
            const SizedBox(
              height: 24,
            ),
          if (divideActions) const Divider(),
          dialogActions,
        ],
      ];

      return PopScope(
        canPop: onClose == null,
        onPopInvokedWithResult: (didPop, result) => !didPop ? onClose?.call() : null,
        child: Dialog(
          child: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: columnChildren,
            ),
          ),
        ),
      );
    },
  );
}
