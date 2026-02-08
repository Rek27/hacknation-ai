import 'package:flutter/material.dart';

import 'package:frontend/config/app_constants.dart';

/// A chat bubble displayed on the agent side while the AI is thinking.
/// Shows three animated bouncing dots inside a styled container that
/// matches the existing agent message bubble appearance.
class ThinkingBubble extends StatelessWidget {
  const ThinkingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppConstants.spacingXs,
        horizontal: AppConstants.spacingMd,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildAvatarSlot(colorScheme),
          const SizedBox(width: AppConstants.spacingSm),
          const _ThinkingDotsContainer(),
        ],
      ),
    );
  }

  Widget _buildAvatarSlot(ColorScheme colorScheme) {
    return Container(
      width: AppConstants.chatAvatarSize,
      height: AppConstants.chatAvatarSize,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.smart_toy_rounded,
          size: AppConstants.iconSizeXs,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Styled container holding the animated dots, matching agent bubble style.
class _ThinkingDotsContainer extends StatelessWidget {
  const _ThinkingDotsContainer();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: AppConstants.elevationMd,
            offset: const Offset(0, AppConstants.elevationSm),
          ),
        ],
      ),
      child: const _BouncingDots(),
    );
  }
}

/// Three dots that bounce up and down with a staggered delay,
/// mimicking a classic "typing indicator" animation.
class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  static const int _dotCount = 3;
  static const double _dotSize = 8.0;
  static const double _bounceHeight = 6.0;
  static const Duration _cycleDuration = Duration(milliseconds: 1200);

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _BouncingDots._cycleDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(
        _BouncingDots._dotCount,
        (int index) => _AnimatedDot(
          controller: _controller,
          index: index,
          dotSize: _BouncingDots._dotSize,
          bounceHeight: _BouncingDots._bounceHeight,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

/// A single dot that animates its vertical position based on a staggered
/// interval within the parent [AnimationController]'s cycle.
class _AnimatedDot extends StatelessWidget {
  const _AnimatedDot({
    required this.controller,
    required this.index,
    required this.dotSize,
    required this.bounceHeight,
    required this.color,
  });

  final AnimationController controller;
  final int index;
  final double dotSize;
  final double bounceHeight;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Each dot occupies a 1/3 window of the cycle, staggered by index.
    final double start = index / _BouncingDots._dotCount;
    final double mid = start + (1.0 / _BouncingDots._dotCount / 2.0);
    final double end = start + (1.0 / _BouncingDots._dotCount);
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final double value = controller.value;
        double offset = 0.0;
        if (value >= start && value < mid) {
          // Going up
          final double t = (value - start) / (mid - start);
          offset = -bounceHeight * Curves.easeOut.transform(t);
        } else if (value >= mid && value < end) {
          // Coming down
          final double t = (value - mid) / (end - mid);
          offset = -bounceHeight * (1.0 - Curves.easeIn.transform(t));
        }
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: dotSize * 0.35),
          child: Transform.translate(offset: Offset(0, offset), child: child),
        );
      },
      child: Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
