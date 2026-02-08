import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

const String _successAssetPath = 'assets/4207-8735-success.riv';

/// Animated Rive illustration shown after all retailer orders are confirmed.
///
/// Loads the success `.riv` asset and plays its first state machine.
/// Falls back to a green checkmark icon if loading fails.
class CheckoutSuccessAnimation extends StatefulWidget {
  const CheckoutSuccessAnimation({super.key, required this.size});

  final double size;

  @override
  State<CheckoutSuccessAnimation> createState() =>
      _CheckoutSuccessAnimationState();
}

class _CheckoutSuccessAnimationState extends State<CheckoutSuccessAnimation> {
  rive.File? _riveFile;
  rive.RiveWidgetController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initRive();
  }

  Future<void> _initRive() async {
    try {
      _riveFile = await rive.File.asset(
        _successAssetPath,
        riveFactory: rive.Factory.rive,
      );
      if (_riveFile == null) return;
      _controller = rive.RiveWidgetController(
        _riveFile!,
        stateMachineSelector: const rive.StateMachineAtIndex(0),
      );
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      print('CheckoutSuccessAnimation._initRive error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _riveFile?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return _buildFallback();
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: rive.RiveWidget(controller: _controller!, fit: rive.Fit.contain),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(
        color: Color(0xFF34C759),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check_rounded,
        size: widget.size * 0.55,
        color: Colors.white,
      ),
    );
  }
}
