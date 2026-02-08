import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

// ─── Switch the active animation here ──────────────────────────────────
// Uncomment ONE line below to try each animation, then hot-restart:
//
// 1) Checkmark Icon by jpereira — clean animated checkmark circle
// const String _activeOrderDoneAssetPath = 'assets/order_done_checkmark.riv';
//
// 2) Success by devf — success icon with fill animation
// const String _activeOrderDoneAssetPath = 'assets/order_done_success.riv';
//
// 3) Success-Done-Completed by Artvier — checkmark with expanding circle
const String _activeOrderDoneAssetPath = 'assets/order_done_success_v2.riv';
//
// 4) Donecheck by Codywhy — minimal done check state machine
// const String _activeOrderDoneAssetPath = 'assets/order_done_donecheck.riv';
//
// 5) Confetti Animation by sergeyz — festive confetti burst
// const String _activeOrderDoneAssetPath = 'assets/order_done_confetti.riv';
// ────────────────────────────────────────────────────────────────────────

/// Animated Rive illustration shown on the order-confirmed screen.
///
/// Loads the selected `.riv` asset and plays its first state machine.
/// Falls back to a green checkmark icon if loading fails.
class OrderDoneAnimation extends StatefulWidget {
  const OrderDoneAnimation({super.key, required this.size});

  final double size;

  @override
  State<OrderDoneAnimation> createState() => _OrderDoneAnimationState();
}

class _OrderDoneAnimationState extends State<OrderDoneAnimation> {
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
        _activeOrderDoneAssetPath,
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
      print('OrderDoneAnimation._initRive error: $e');
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
