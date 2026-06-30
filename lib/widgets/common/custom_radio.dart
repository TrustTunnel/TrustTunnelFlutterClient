// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';

class CustomRadio<T> extends StatelessWidget {
  const CustomRadio({
    super.key,
    required this.value,
    required this.groupValue,
    this.activeColor,
    this.onChanged,
  });

  final T value;
  final T groupValue;
  final Color? activeColor;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) => Transform.scale(
    scale: context.scaleFactor,
    child: SizedBox.square(
      dimension: 24 * context.scaleFactor,
      child: Radio<T>(
        value: value,
        activeColor: activeColor,
        splashRadius: 0,
        groupValue: groupValue,
        onChanged: onChanged,
      ),
    ),
  );
}
