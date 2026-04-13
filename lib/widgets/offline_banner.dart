import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _showRestoredMessage = false;
  bool _visible = false;
  Timer? _hideTimer;
  bool? _previousOnline;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _handleConnectivityChange(bool isOnline) {
    if (_previousOnline == null) {
      _previousOnline = isOnline;
      if (!isOnline) setState(() => _visible = true);
      return;
    }

    if (!isOnline && _previousOnline == true) {
      // Se perdió la conexión
      _hideTimer?.cancel();
      setState(() {
        _showRestoredMessage = false;
        _visible = true;
      });
    } else if (isOnline && _previousOnline == false) {
      // Se recuperó la conexión
      _hideTimer?.cancel();
      setState(() {
        _showRestoredMessage = true;
        _visible = true;
      });
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _visible = false);
      });
    }

    _previousOnline = isOnline;
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityService>().isOnline;
    _handleConnectivityChange(isOnline);

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: _visible ? AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: _showRestoredMessage
            ? const Color(0xFF1A3A1A)
            : const Color(0xFF2A2A2A),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showRestoredMessage
                  ? Icons.wifi_outlined
                  : Icons.wifi_off_outlined,
              color: _showRestoredMessage
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFAAAAAA),
              size: 14,
            ),
            const SizedBox(width: 8),
            Text(
              _showRestoredMessage
                  ? 'Conexión restaurada'
                  : 'Sin conexión — mostrando contenido guardado',
              style: TextStyle(
                color: _showRestoredMessage
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFAAAAAA),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ) : const SizedBox.shrink(),
    );
  }
}