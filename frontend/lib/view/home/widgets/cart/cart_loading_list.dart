import 'package:flutter/material.dart';
import 'package:frontend/config/app_constants.dart';

/// List of cart skeletons with an optional loading message appended after items.
class CartLoadingList extends StatelessWidget {
  const CartLoadingList({
    super.key,
    this.count = 5,
    this.loadingText = 'Searching retailers for the best deals...',
  });

  final int count;
  final String? loadingText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<Widget> children =
        List<Widget>.generate(count, (i) => const _SkeletonCartItem()).expand((
          w,
        ) sync* {
          yield w;
          yield const SizedBox(height: AppConstants.spacingMd);
        }).toList();

    if (loadingText != null) {
      children.add(const SizedBox(height: AppConstants.spacingSm));
      children.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: AppConstants.iconSizeXs,
              height: AppConstants.iconSizeXs,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spacingMd),
            Text(
              loadingText!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
      children.add(const SizedBox(height: AppConstants.spacingMd));
    }

    return ListView(
      padding: const EdgeInsets.only(top: AppConstants.spacingMd),
      children: children,
    );
  }
}

/// Reusable pulsing skeleton box. Fades in/out to suggest loading.
class _AnimatedSkeletonBox extends StatefulWidget {
  const _AnimatedSkeletonBox({required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<_AnimatedSkeletonBox> createState() => _AnimatedSkeletonBoxState();
}

class _AnimatedSkeletonBoxState extends State<_AnimatedSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.10,
      end: 0.22,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color base = Theme.of(context).colorScheme.surfaceContainerHigh;
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: base.withValues(alpha: _opacity.value),
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          ),
        );
      },
    );
  }
}

/// Skeleton resembling a cart item tile.
class _SkeletonCartItem extends StatelessWidget {
  const _SkeletonCartItem();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Row(
        children: [
          const _AnimatedSkeletonBox(
            width: AppConstants.skeletonImageSize,
            height: AppConstants.skeletonImageSize,
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _AnimatedSkeletonBox(
                  width: AppConstants.skeletonTitleWidth,
                  height: AppConstants.skeletonTitleHeight,
                ),
                SizedBox(height: AppConstants.spacingSm),
                _AnimatedSkeletonBox(
                  width: AppConstants.skeletonSubtitleWidth,
                  height: AppConstants.skeletonSubtitleHeight,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
