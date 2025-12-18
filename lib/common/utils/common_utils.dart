import 'package:flutter/material.dart';
import 'package:trusttunnel/data/model/breakpoint.dart';

class CommonUtils {
  static const widthBreakpointXS = 600;

  static const widthBreakpointS = 904;
  const CommonUtils._();

  static double getScreenWidth() =>
      WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width /
      WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

  static Breakpoint getBreakpointByWidth(double width) => switch (width) {
    >= CommonUtils.widthBreakpointS => Breakpoint.M,
    >= CommonUtils.widthBreakpointXS => Breakpoint.S,
    _ => Breakpoint.XS,
  };

  static Breakpoint getBreakpoint() => getBreakpointByWidth(getScreenWidth());
}
