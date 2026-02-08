import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

// ─── Switch the active animation here ──────────────────────────────────
// Uncomment ONE line below to try each animation, then hot-restart:
//
// 1) Search Icon by JcToon — cute dog with magnifying glass (search theme)
// const String _activeAssetPath = 'assets/empty_cart_search_icon.riv';
//
// 2) Little Fella by selleslaghbert — idle character with cursor tracking
// const String _activeAssetPath = 'assets/empty_cart_little_fella.riv';
//
// 3) Character Facial Animation by Ryuhei — random facial expressions
// const String _activeAssetPath = 'assets/empty_cart_facial_character.riv';
//
// 4) Avatar Pack by drawsgood — 3 avatars with idle, happy, sad states
const String _activeAssetPath = 'assets/empty_cart_avatar_pack.riv';
//
// 5) Sad Blob by MiniCubeVR — simple sad character
// const String _activeAssetPath = 'assets/empty_cart_sad_blob.riv';
// ────────────────────────────────────────────────────────────────────────

/// Animated Rive illustration shown in the empty cart state.
///
/// Loads the selected `.riv` asset and plays its default state machine.
/// Falls back to an [Icons.shopping_cart_outlined] icon if loading fails.
class CartEmptyAnimation extends StatefulWidget {
  const CartEmptyAnimation({super.key, required this.size});

  final double size;

  @override
  State<CartEmptyAnimation> createState() => _CartEmptyAnimationState();
}

class _CartEmptyAnimationState extends State<CartEmptyAnimation> {
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
        _activeAssetPath,
        riveFactory: rive.Factory.rive,
      );
      if (_riveFile == null) return;
      _controller = rive.RiveWidgetController(_riveFile!);
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      print('CartEmptyAnimation._initRive error: $e');
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
      child: Icon(
        Icons.shopping_cart_outlined,
        size: widget.size * 0.4,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
