import 'package:flutter/material.dart';
import 'package:trusttunnel/widgets/arb_parser/arb_item.dart';
import 'package:trusttunnel/widgets/arb_parser/arb_parser_base.dart';

class ArbParser extends StatelessWidget {
  final String data;
  final Color? color;
  final TextAlign? textAlign;
  final FontWeight? boldWeight;
  final TextStyle? plainStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  const ArbParser({
    super.key,
    required this.data,
    this.color,
    this.plainStyle,
    this.textAlign,
    this.boldWeight = FontWeight.w600,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final mainStyle = plainStyle ?? DefaultTextStyle.of(context).style;

    return ArbParserBase(
      data: data,
      builder: (items) => _formatItems(
        items: items,
        context: context,
        mainStyle: mainStyle,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }

  Widget _formatItems({
    required List<ArbItem> items,
    required BuildContext context,
    TextStyle? mainStyle,
    int? maxLines,
    TextOverflow? overflow,
  }) => LayoutBuilder(
    builder: (context, constraints) => Text.rich(
      TextSpan(
        children: items
            .map(
              (item) => switch (item.type) {
                ArbItemType.plain => TextSpan(
                  text: item.text!,
                  style: mainStyle?.copyWith(
                    color: color,
                  ),
                ),
                ArbItemType.bold => TextSpan(
                  text: item.text!,
                  style: mainStyle?.copyWith(
                    color: color,
                    fontWeight: boldWeight,
                  ),
                ),
              },
            )
            .toList(),
      ),
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
    ),
  );
}
