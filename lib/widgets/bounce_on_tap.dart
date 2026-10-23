import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Hace rebotar a su hijo (escala 0,75 → 1 pasándose un poco) al tocarlo, con
/// el mismo efecto que los iconos de la barra inferior.
///
/// Solo escucha los punteros, sin entrar en la arena de gestos, así que el
/// botón que envuelve sigue recibiendo el tap con normalidad. Si el dedo se
/// desplaza (scroll) no se considera un toque y no rebota.
class BounceOnTap extends StatefulWidget {
  final Widget child;

  const BounceOnTap({super.key, required this.child});

  @override
  State<BounceOnTap> createState() => _BounceOnTapState();
}

class _BounceOnTapState extends State<BounceOnTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    value: 1,
  );
  late final Animation<double> _scale = Tween<double>(begin: 0.75, end: 1)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  Offset? _downPosition;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerUp(PointerUpEvent event) {
    final down = _downPosition;
    _downPosition = null;
    if (down == null) return;
    if ((event.position - down).distance > kTouchSlop) return;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) => _downPosition = e.position,
      onPointerUp: _onPointerUp,
      onPointerCancel: (_) => _downPosition = null,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
