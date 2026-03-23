import 'package:flutter/material.dart';

class RotatingWidget extends StatefulWidget {
  final Duration duration;
  final Widget child;

  const RotatingWidget({
    super.key,
    required this.duration,
    required this.child,
  });

  @override
  State<RotatingWidget> createState() => _RotatingWidgetState();
}

class _RotatingWidgetState extends State<RotatingWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    );

    _animation = Tween(
      begin: 1.0,
      end: 0.0,
    ).animate(_controller);

    _controller.repeat();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _animation,
    child: widget.child,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
