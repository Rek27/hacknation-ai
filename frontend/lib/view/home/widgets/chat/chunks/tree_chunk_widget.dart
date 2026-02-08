import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/config/app_constants.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:frontend/view/home/widgets/chat/chat_controller.dart';
import 'package:frontend/view/home/widgets/chat/chunks/category_tile.dart';

/// Renders a [TreeChunk] as an Apple-inspired pill-based category selector.
///
/// Three depth levels are visually distinct: capsule tiles (L0),
/// compact pills (L1), and micro-chips (L2). Subcategories expand with
/// smooth size + fade animations and staggered entrance.
class TreeChunkWidget extends StatelessWidget {
  const TreeChunkWidget({
    super.key,
    required this.chunk,
    required this.messageId,
    required this.isDisabled,
  });

  final TreeChunk chunk;
  final String messageId;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    // Watch the controller so we rebuild when selections change.
    context.watch<ChatController>();
    return AnimatedOpacity(
      duration: AppConstants.durationMedium,
      opacity: isDisabled ? AppConstants.treeDisabledOpacity : 1.0,
      child: IgnorePointer(
        ignoring: isDisabled,
        child: Container(
          margin: const EdgeInsets.only(top: AppConstants.spacingSm),
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TreeHeader(
                emoji: chunk.category.emoji,
                label: chunk.category.label,
              ),
              const SizedBox(height: AppConstants.spacingSm),
              _CategoryLevel(
                categories: chunk.category.subcategories,
                ancestors: <String>[chunk.category.label],
                depth: 0,
                messageId: messageId,
                isDisabled: isDisabled,
              ),
              if (!isDisabled) ...[
                const SizedBox(height: AppConstants.spacingMd),
                _SubmitTreeButton(
                  onPressed: () {
                    context.read<ChatController>().submitTree(messageId);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _TreeHeader
// ─────────────────────────────────────────────────────────────────────────────

/// Subtle section heading showing the root category emoji and label.
class _TreeHeader extends StatelessWidget {
  const _TreeHeader({required this.emoji, required this.label});

  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: AppConstants.treePillEmojiSizeL0)),
        const SizedBox(width: AppConstants.spacingSm),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _CategoryLevel
// ─────────────────────────────────────────────────────────────────────────────

/// Renders a list of categories at a given [depth] as a flowing [Wrap].
/// Each pill is followed by its expandable subcategory group.
class _CategoryLevel extends StatelessWidget {
  const _CategoryLevel({
    required this.categories,
    required this.ancestors,
    required this.depth,
    required this.messageId,
    required this.isDisabled,
  });

  final List<Category> categories;
  final List<String> ancestors;
  final int depth;
  final String messageId;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final ChatController controller = context.read<ChatController>();
    final double spacing =
        depth == 0 ? AppConstants.spacingSm : AppConstants.spacingXs;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: categories.map((Category cat) {
        final String path = controller.buildLabelPath(ancestors, cat.label);
        final CategoryNodeState state = controller.getNodeState(
          messageId,
          path,
          initialSelected: cat.isSelected,
        );
        final bool shouldExpand =
            state.isSelected && cat.subcategories.isNotEmpty;
        return _CategoryColumn(
          pill: CategoryPill(
            emoji: cat.emoji,
            label: cat.label,
            isSelected: state.isSelected,
            isDisabled: isDisabled,
            onTap: () {
              controller.toggleCategorySelection(messageId, path);
            },
            depth: depth,
          ),
          isExpanded: shouldExpand,
          depth: depth,
          subcategories: cat.subcategories,
          ancestors: [...ancestors, cat.label],
          messageId: messageId,
          isDisabled: isDisabled,
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _CategoryColumn
// ─────────────────────────────────────────────────────────────────────────────

/// Pairs a pill with its expandable subcategory section in a vertical column.
class _CategoryColumn extends StatelessWidget {
  const _CategoryColumn({
    required this.pill,
    required this.isExpanded,
    required this.depth,
    required this.subcategories,
    required this.ancestors,
    required this.messageId,
    required this.isDisabled,
  });

  final Widget pill;
  final bool isExpanded;
  final int depth;
  final List<Category> subcategories;
  final List<String> ancestors;
  final String messageId;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pill,
        _ExpandableSubcategories(
          isExpanded: isExpanded,
          depth: depth,
          subcategories: subcategories,
          ancestors: ancestors,
          messageId: messageId,
          isDisabled: isDisabled,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ExpandableSubcategories
// ─────────────────────────────────────────────────────────────────────────────

/// Animates the reveal / hide of a subcategory group using [SizeTransition]
/// combined with [FadeTransition] for a polished expand / collapse effect.
class _ExpandableSubcategories extends StatefulWidget {
  const _ExpandableSubcategories({
    required this.isExpanded,
    required this.depth,
    required this.subcategories,
    required this.ancestors,
    required this.messageId,
    required this.isDisabled,
  });

  final bool isExpanded;
  final int depth;
  final List<Category> subcategories;
  final List<String> ancestors;
  final String messageId;
  final bool isDisabled;

  @override
  State<_ExpandableSubcategories> createState() =>
      _ExpandableSubcategoriesState();
}

class _ExpandableSubcategoriesState extends State<_ExpandableSubcategories>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _sizeFactor;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppConstants.treeExpandDuration,
      value: widget.isExpanded ? 1.0 : 0.0,
    );
    _sizeFactor = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      reverseCurve: const Interval(0.2, 1.0, curve: Curves.easeIn),
    );
  }

  @override
  void didUpdateWidget(_ExpandableSubcategories oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final int childDepth = widget.depth + 1;
    // Cap at 3 levels (0, 1, 2).
    if (childDepth > 2) return const SizedBox.shrink();
    return SizeTransition(
      sizeFactor: _sizeFactor,
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: _opacity,
        child: Padding(
          padding: EdgeInsets.only(
            left: AppConstants.spacingMd,
            top: AppConstants.spacingXs,
            bottom: AppConstants.spacingXs,
          ),
          child: Container(
            padding: const EdgeInsets.only(left: AppConstants.spacingSm),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  width: AppConstants.treeIndentBarWidth,
                ),
              ),
            ),
            child: _StaggeredCategoryLevel(
              categories: widget.subcategories,
              ancestors: widget.ancestors,
              depth: childDepth,
              messageId: widget.messageId,
              isDisabled: widget.isDisabled,
              parentAnimation: _controller,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _StaggeredCategoryLevel
// ─────────────────────────────────────────────────────────────────────────────

/// Like [_CategoryLevel] but wraps each pill in a staggered slide + fade
/// animation driven by the parent expand controller.
class _StaggeredCategoryLevel extends StatelessWidget {
  const _StaggeredCategoryLevel({
    required this.categories,
    required this.ancestors,
    required this.depth,
    required this.messageId,
    required this.isDisabled,
    required this.parentAnimation,
  });

  final List<Category> categories;
  final List<String> ancestors;
  final int depth;
  final String messageId;
  final bool isDisabled;
  final AnimationController parentAnimation;

  @override
  Widget build(BuildContext context) {
    final ChatController controller = context.read<ChatController>();
    final double spacing = AppConstants.spacingXs;
    final int total = categories.length;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: List<Widget>.generate(total, (int index) {
        final Category cat = categories[index];
        final String path = controller.buildLabelPath(ancestors, cat.label);
        final CategoryNodeState state = controller.getNodeState(
          messageId,
          path,
          initialSelected: cat.isSelected,
        );
        final bool shouldExpand =
            state.isSelected && cat.subcategories.isNotEmpty;
        // Stagger interval: each pill starts a little later.
        final double start = (index / total) * 0.4;
        final double end = start + 0.6;
        final Animation<double> itemOpacity = CurvedAnimation(
          parent: parentAnimation,
          curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0),
              curve: Curves.easeOut),
        );
        final Animation<Offset> itemSlide = Tween<Offset>(
          begin: const Offset(0, -0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: parentAnimation,
          curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0),
              curve: Curves.easeOutCubic),
        ));
        return SlideTransition(
          position: itemSlide,
          child: FadeTransition(
            opacity: itemOpacity,
            child: _CategoryColumn(
              pill: CategoryPill(
                emoji: cat.emoji,
                label: cat.label,
                isSelected: state.isSelected,
                isDisabled: isDisabled,
                onTap: () {
                  controller.toggleCategorySelection(messageId, path);
                },
                depth: depth,
              ),
              isExpanded: shouldExpand,
              depth: depth,
              subcategories: cat.subcategories,
              ancestors: [...ancestors, cat.label],
              messageId: messageId,
              isDisabled: isDisabled,
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _SubmitTreeButton
// ─────────────────────────────────────────────────────────────────────────────

/// Minimal submit button aligned to the trailing edge.
class _SubmitTreeButton extends StatelessWidget {
  const _SubmitTreeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.check_rounded, size: AppConstants.iconSizeXs),
        label: const Text('Submit Selection'),
      ),
    );
  }
}
