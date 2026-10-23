import 'dart:async';

import 'package:flutter/material.dart';

/// Hace aparecer a su hijo con un fundido y un pequeño deslizamiento. Con
/// [animate] a `false` lo pinta directamente.
///
/// - [expand]: además abre su altura desde 0, para que los elementos de debajo
///   bajen suavemente (inserciones en un listado ya visible).
/// - [delay]: retraso antes de empezar, para escalonar varios elementos.
///
/// Se debe usar con una key estable (p. ej. `ValueKey(article.id)`) para que
/// los elementos ya visibles conserven su estado y no se vuelvan a animar.
class AppearAnimation extends StatefulWidget {
  final Widget child;
  final bool animate;
  final bool expand;
  final Duration delay;
  final Duration duration;

  const AppearAnimation({
    super.key,
    required this.child,
    this.animate = true,
    this.expand = true,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 350),
  });

  /// Retraso escalonado para el elemento en la posición [index].
  static Duration staggerDelay(int index) =>
      Duration(milliseconds: 60 * index.clamp(0, 8));

  @override
  State<AppearAnimation> createState() => _AppearAnimationState();
}

class _AppearAnimationState extends State<AppearAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.animate ? 0 : 1,
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    if (!widget.animate) return;
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _delayTimer = Timer(widget.delay, _controller.forward);
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, widget.expand ? -0.1 : 0.15),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
    if (!widget.expand) return content;
    return SizeTransition(
      sizeFactor: _curve,
      alignment: Alignment.topCenter,
      child: content,
    );
  }
}
