
import 'package:flutter/cupertino.dart';
// Connection Button - Main connect/disconnect button
// Large circular button with state-based styling

import 'package:flutter/material.dart';
import '../../core/theme/hamo_colors.dart';
import '../../core/constants/hamo_constants.dart';
import '../../core/vpn/vpn_service.dart';

class ConnectionButton extends StatelessWidget {
  final VpnConnectionState state;
  final VoidCallback onTap;

  const ConnectionButton({
    super.key,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isConnecting = state == VpnConnectionState.connecting ||
        state == VpnConnectionState.preparing ||
        state == VpnConnectionState.authenticating;
    final isConnected = state == VpnConnectionState.connected;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: HamoConstants.animationDuration,
        curve: Curves.easeInOut,
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isConnected
              ? HamoColors.connectedGradient
              : isConnecting
                  ? const LinearGradient(
                      colors: [HamoColors.connectingOrange, HamoColors.primaryOrangeLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [HamoColors.primaryOrangeDark, HamoColors.primaryOrange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
          boxShadow: [
            BoxShadow(
              color: (isConnected ? HamoColors.connectedGreen : HamoColors.primaryOrange)
                  .withOpacity(isConnecting ? 0.3 : 0.5),
              blurRadius: isConnecting ? 30 : 20,
              spreadRadius: isConnecting ? 5 : 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse ring when connecting
            if (isConnecting)
              _PulseRing(color: HamoColors.primaryOrange),
            // Inner content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIcon(isConnected, isConnecting),
                const SizedBox(height: 8),
                Text(
                  _getLabel(),
                  style: const TextStyle(
                    color: HamoColors.darkTextOnPrimary,
                    fontFamily: 'SFPro',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(bool isConnected, bool isConnecting) {
    if (isConnecting) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(HamoColors.darkTextOnPrimary),
          strokeWidth: 3,
        ),
      );
    }

    return Icon(
      isConnected ? CupertinoIcons.power : CupertinoIcons.power,
      color: HamoColors.darkTextOnPrimary,
      size: 48,
    );
  }

  String _getLabel() {
    switch (state) {
      case VpnConnectionState.disconnected:
        return 'Connect';
      case VpnConnectionState.preparing:
        return 'Preparing...';
      case VpnConnectionState.connecting:
        return 'Connecting...';
      case VpnConnectionState.authenticating:
        return 'Authenticating...';
      case VpnConnectionState.connected:
        return 'Disconnect';
      case VpnConnectionState.disconnecting:
        return 'Disconnecting...';
      case VpnConnectionState.error:
        return 'Retry';
    }
  }
}

class _PulseRing extends StatefulWidget {
  final Color color;

  const _PulseRing({required this.color});

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.4, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.color,
                  width: 3,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}