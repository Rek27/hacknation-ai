import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

// ─── Switch the active animation here ──────────────────────────────────
// Uncomment ONE line below to try each animation, then hot-restart:
//
// 1) Vehicle Loader by pedroalpera — delivery truck that drives away on completion
const String _activeCheckoutAssetPath = 'assets/11929-22748-simple-loading.riv';
//
// 2) Loading to Success/Failure by khadsemayur — loading → checkmark transition
// const String _activeCheckoutAssetPath = 'assets/checkout_loading_success.riv';
//
// 3) Spinner by benjad — smooth spinner with state transitions (check / cross)
// const String _activeCheckoutAssetPath = 'assets/checkout_spinner.riv';
// ────────────────────────────────────────────────────────────────────────

/// Animated Rive illustration shown while orders are being placed.
///
/// Loads the selected `.riv` asset and plays its first state machine.
/// Uses [StateMachineAtIndex] to avoid failures on files without a
/// default state machine marker.
/// Falls back to a [CircularProgressIndicator] if loading fails.
class CheckoutLoadingAnimation extends StatefulWidget {
  const CheckoutLoadingAnimation({super.key, required this.size});

  final double size;

  @override
  State<CheckoutLoadingAnimation> createState() =>
      _CheckoutLoadingAnimationState();
}

class _CheckoutLoadingAnimationState extends State<CheckoutLoadingAnimation> {
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
        _activeCheckoutAssetPath,
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
      print('CheckoutLoadingAnimation._initRive error: $e');
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
      return _buildFallback(context);
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: rive.RiveWidget(controller: _controller!, fit: rive.Fit.contain),
    );
  }

  Widget _buildFallback(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: SizedBox(
          width: widget.size * 0.4,
          height: widget.size * 0.4,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
