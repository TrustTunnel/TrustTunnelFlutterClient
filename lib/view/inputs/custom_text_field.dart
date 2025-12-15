import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vpn/common/assets/asset_icons.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/extensions/theme_extensions.dart';
import 'package:vpn/view/custom_icon.dart';

class CustomTextField extends StatefulWidget {
  final String? value;
  final String? hint;
  final String? helper;
  final String? error;
  final bool enabled;
  final bool readOnly;
  final String? label;
  final int? maxLines;
  final int? minLines;
  final bool showClearButton;
  final Widget? suffixIcon;
  final int? maxLength;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final SpellCheckService? spellCheckService;

  const CustomTextField({
    super.key,
    this.value,
    this.hint,
    this.helper,
    this.error,
    this.enabled = true,
    this.readOnly = false,
    this.showClearButton = true,
    this.label,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.autofocus = false,
    this.inputFormatters,
    this.controller,
    this.onChanged,
    this.validator,
    this.spellCheckService,
  }) : suffixIcon = null,
       assert(
         (maxLines == null) || (minLines == null) || (maxLines >= minLines),
         "minLines can't be greater than maxLines",
       );

  const CustomTextField.customSuffixIcon({
    super.key,
    required this.suffixIcon,
    this.value,
    this.hint,
    this.helper,
    this.error,
    this.enabled = true,
    this.readOnly = false,
    this.label,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.autofocus = false,
    this.inputFormatters,
    this.controller,
    this.onChanged,
    this.validator,
    this.spellCheckService,
  }) : showClearButton = false,
       assert(suffixIcon != null),
       assert(
         (maxLines == null) || (minLines == null) || (maxLines >= minLines),
         "minLines can't be greater than maxLines",
       );

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late final TextEditingController _controller;
  late final FocusScopeNode _focusNode;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _controller = widget.controller ?? TextEditingController();
    _controller.text = widget.value ?? '';
    _focusNode = FocusScopeNode(traversalEdgeBehavior: TraversalEdgeBehavior.parentScope);
  }

  @override
  void didUpdateWidget(CustomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newText = widget.value;
    if (newText != null && _controller.text != newText) {
      _controller.text = newText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final spellCheckConfig = widget.spellCheckService != null
        ? SpellCheckConfiguration(
            spellCheckService: widget.spellCheckService!,
            misspelledTextStyle: context.theme.extension<CustomMissSpelledTextTheme>()?.apply(
              context.textTheme.bodyLarge ?? DefaultTextStyle.of(context).style,
            ),
          )
        : null;

    return FocusScope(
      node: _focusNode,
      skipTraversal: !widget.enabled,
      onFocusChange: _scrollToStartOnFocusLost,
      child: ListenableBuilder(
        listenable: _focusNode,
        builder: (context, child) => TextFormField(
          controller: _controller,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          scrollController: _scrollController,
          cursorWidth: 1,
          autofocus: widget.autofocus,
          cursorHeight: context.textTheme.bodyLarge?.fontSize,
          textAlignVertical: TextAlignVertical.center,
          inputFormatters: widget.inputFormatters,
          autovalidateMode: AutovalidateMode.always,
          onChanged: widget.onChanged,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          maxLength: _focusNode.hasFocus ? widget.maxLength : null,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          spellCheckConfiguration: spellCheckConfig,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helper,
            labelText: widget.label,
            errorText: widget.error,
            errorMaxLines: 3,
            suffixIcon: Padding(
              padding: const EdgeInsets.all(4),
              child:
                  widget.suffixIcon ??
                  (widget.error != null
                      ? Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: CustomIcon.medium(
                            icon: AssetIcons.error,
                            color: context.colors.error,
                          ),
                        )
                      : const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
  }

  void _scrollToStartOnFocusLost(bool hasFocus) {
    if (!hasFocus) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    // Dispose of only the controller created internally
    if (widget.controller == null) {
      _controller.dispose();
    }
    _scrollController.dispose();
    _focusNode.dispose();

    super.dispose();
  }
}
