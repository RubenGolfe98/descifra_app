import 'dart:async';

import 'package:flutter/material.dart';

/// Encoge ligeramente su contenido mientras está pulsado.
///
/// [builder] recibe el callback que indica si está pulsado. Con un `InkWell`
/// se pasa a `onHighlightChanged`, así el efecto sigue al resaltado y se cancela
/// solo al hacer scroll. Con un `GestureDetector`, se llama desde `onTapDown`
/// (true) y `onTapUp`/`onTapCancel` (false).
///
/// En un toque rápido el encogido se mantiene al menos [minPressDuration] para
/// que se aprecie igual que al mantener pulsado.
class PressScale extends StatefulWidget {
  final Widget Function(ValueChanged<bool> onPressedChanged) builder;
  final double pressedScale;
  final Duration minPressDuration;

  const PressScale({
    super.key,
    required this.builder,
    this.pressedScale = 0.98,
    this.minPressDuration = const Duration(milliseconds: 120),
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;
  final _pressWatch = Stopwatch();
  Timer? _releaseTimer;

  void _onPressedChanged(bool value) {
    _releaseTimer?.cancel();
    if (value) {
      _pressWatch
        ..reset()
        ..start();
      if (!_pressed) setState(() => _pressed = true);
      return;
    }
    final remaining = widget.minPressDuration - _pressWatch.elapsed;
    if (remaining <= Duration.zero) {
      if (_pressed) setState(() => _pressed = false);
    } else {
      _releaseTimer = Timer(remaining, () {
        if (mounted) setState(() => _pressed = false);
      });
    }
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? widget.pressedScale : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: widget.builder(_onPressedChanged),
    );
  }
}
