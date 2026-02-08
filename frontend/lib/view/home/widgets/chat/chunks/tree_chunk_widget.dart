import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/config/app_constants.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:frontend/view/home/widgets/chat/chat_controller.dart';
import 'package:frontend/view/home/widgets/chat/chunks/category_tile.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DFS helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Walks the category tree depth-first and assigns a sequential index to every
/// initially-visible item. Returns the map (labelPath → index) and advances
/// [counter] past all assigned indices.
///
/// "Initially visible" means the item itself is always counted, plus its
/// children are counted recursively when the category is pre-selected.
Map<String, int> _buildDfsIndexMap(
  List<Category> categories,
  List<String> ancestors,
  ChatController controller,
  String messageId,
  _Counter counter,
) {
  final Map<String, int> map = <String, int>{};
  for (final Category cat in categories) {
    final String path = controller.buildLabelPath(ancestors, cat.label);
    map[path] = counter.value++;
    final CategoryNodeState state = controller.getNodeState(
      messageId,
      path,
      initialSelected: cat.isSelected,
    );
    if (state.isSelected && cat.subcategories.isNotEmpty) {
      map.addAll(
        _buildDfsIndexMap(
          cat.subcategories,
          <String>[...ancestors, cat.label],
          controller,
          messageId,
          counter,
        ),
      );
    }
  }
  return map;
}

/// Simple mutable counter passed through the DFS walk.
class _Counter {
  int value;
  _Counter(this.value);
}

// ─────────────────────────────────────────────────────────────────────────────
//  TreeChunkWidget
// ─────────────────────────────────────────────────────────────────────────────

/// Renders a [TreeChunk] as an Apple-inspired category selector.
///
/// On first mount the entire visible tree builds up item-by-item in strict
/// depth-first order: header → first L0 pill → its L1 children → their L2
/// children → next L0 pill → … → submit button.
class TreeChunkWidget extends StatefulWidget {
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
  State<TreeChunkWidget> createState() => _TreeChunkWidgetState();
}

class _TreeChunkWidgetState extends State<TreeChunkWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: AppConstants.treeEntranceDuration,
      value: widget.isDisabled ? 1.0 : 0.0,
    );
    if (!widget.isDisabled) {
      _entranceController.forward();
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  /// Wraps [child] in a sequential fade + slide driven by the entrance
  /// controller. [index] and [total] determine the non-overlapping time slot.
  Widget _animateItem(int index, int total, Widget child) {
    if (total <= 1) return child;
    final double start = index / total;
    final double end = (index + 1) / total;
    final Animation<double> opacity = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    final Animation<Offset> slide =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          ),
        );
    return SlideTransition(
      position: slide,
      child: FadeTransition(opacity: opacity, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final ChatController controller = context.watch<ChatController>();

    // Build DFS index map for the entrance animation.
    // Index 0 = header, then all categories depth-first, then submit button.
    final _Counter counter = _Counter(1); // start at 1 (header is 0)
    final Map<String, int> dfsMap = _buildDfsIndexMap(
      widget.chunk.category.subcategories,
      <String>[widget.chunk.category.label],
      controller,
      widget.messageId,
      counter,
    );
    final int totalItems =
        counter.value + (widget.isDisabled ? 0 : 1); // +1 for submit button

    return AnimatedOpacity(
      duration: AppConstants.durationMedium,
      opacity: widget.isDisabled ? AppConstants.treeDisabledOpacity : 1.0,
      child: IgnorePointer(
        ignoring: widget.isDisabled,
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
          child: AnimatedBuilder(
            animation: _entranceController,
            builder: (BuildContext context, Widget? _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _animateItem(
                    0,
                    totalItems,
                    _TreeHeader(
                      emoji: widget.chunk.category.emoji,
                      label: widget.chunk.category.label,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingSm),
                  _TopLevelCategoryList(
                    categories: widget.chunk.category.subcategories,
                    rootLabel: widget.chunk.category.label,
                    messageId: widget.messageId,
                    isDisabled: widget.isDisabled,
                    entranceController: _entranceController,
                    dfsMap: dfsMap,
                    totalItems: totalItems,
                    animateItem: _animateItem,
                  ),
                  if (!widget.isDisabled) ...[
                    const SizedBox(height: AppConstants.spacingMd),
                    _animateItem(
                      totalItems - 1,
                      totalItems,
                      _SubmitTreeButton(
                        onPressed: () {
                          context.read<ChatController>().submitTree(
                            widget.messageId,
                          );
                        },
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _TreeHeader
// ─────────────────────────────────────────────────────────────────────────────

class _TreeHeader extends StatelessWidget {
  const _TreeHeader({required this.emoji, required this.label});

  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Row(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: AppConstants.treePillEmojiSizeL0),
        ),
        const SizedBox(width: AppConstants.spacingSm),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _TopLevelCategoryList
// ─────────────────────────────────────────────────────────────────────────────

typedef _AnimateItemFn = Widget Function(int index, int total, Widget child);

/// Renders depth-0 pills in a vertical column. Each pill is wrapped in the
/// entrance animation using its DFS index, followed by its expandable children.
class _TopLevelCategoryList extends StatelessWidget {
  const _TopLevelCategoryList({
    required this.categories,
    required this.rootLabel,
    required this.messageId,
    required this.isDisabled,
    required this.entranceController,
    required this.dfsMap,
    required this.totalItems,
    required this.animateItem,
  });

  final List<Category> categories;
  final String rootLabel;
  final String messageId;
  final bool isDisabled;
  final AnimationController entranceController;
  final Map<String, int> dfsMap;
  final int totalItems;
  final _AnimateItemFn animateItem;

  @override
  Widget build(BuildContext context) {
    final ChatController controller = context.read<ChatController>();
    final List<String> ancestors = <String>[rootLabel];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(categories.length, (int i) {
        final Category cat = categories[i];
        final String path = controller.buildLabelPath(ancestors, cat.label);
        final CategoryNodeState state = controller.getNodeState(
          messageId,
          path,
          initialSelected: cat.isSelected,
        );
        final bool shouldExpand =
            state.isSelected && cat.subcategories.isNotEmpty;
        final int dfsIndex = dfsMap[path] ?? 0;
        return Padding(
          padding: const EdgeInsets.only(top: AppConstants.spacingXs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              animateItem(
                dfsIndex,
                totalItems,
                CategoryPill(
                  emoji: cat.emoji,
                  label: cat.label,
                  isSelected: state.isSelected,
                  isDisabled: isDisabled,
                  onTap: () {
                    controller.toggleCategorySelection(messageId, path);
                  },
                  depth: 0,
                ),
              ),
              _ExpandableSubcategories(
                key: ValueKey<String>('expand_$path'),
                isExpanded: shouldExpand,
                subcategories: cat.subcategories,
                ancestors: [...ancestors, cat.label],
                messageId: messageId,
                isDisabled: isDisabled,
                entranceController: entranceController,
                dfsMap: dfsMap,
                totalItems: totalItems,
                animateItem: animateItem,
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ExpandableSubcategories
// ─────────────────────────────────────────────────────────────────────────────

/// Animates the reveal / hide of a depth-1 subcategory group.
/// Individual pills inside use the global entrance controller for their
/// initial build-up, and the local expand controller for user-triggered
/// expand / collapse.
class _ExpandableSubcategories extends StatefulWidget {
  const _ExpandableSubcategories({
    super.key,
    required this.isExpanded,
    required this.subcategories,
    required this.ancestors,
    required this.messageId,
    required this.isDisabled,
    required this.entranceController,
    required this.dfsMap,
    required this.totalItems,
    required this.animateItem,
  });

  final bool isExpanded;
  final List<Category> subcategories;
  final List<String> ancestors;
  final String messageId;
  final bool isDisabled;
  final AnimationController entranceController;
  final Map<String, int> dfsMap;
  final int totalItems;
  final _AnimateItemFn animateItem;

  @override
  State<_ExpandableSubcategories> createState() =>
      _ExpandableSubcategoriesState();
}

class _ExpandableSubcategoriesState extends State<_ExpandableSubcategories>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expandController;
  late final Animation<double> _sizeFactor;

  /// Whether this group was already expanded when first mounted (pre-selected
  /// from the API). In that case the expand container starts open and only the
  /// entrance controller drives individual pill visibility.
  late final bool _wasInitiallyExpanded;

  @override
  void initState() {
    super.initState();
    _wasInitiallyExpanded = widget.isExpanded;
    _expandController = AnimationController(
      vsync: this,
      duration: AppConstants.treeExpandDuration,
      value: widget.isExpanded ? 1.0 : 0.0,
    );
    _sizeFactor = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(_ExpandableSubcategories oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return SizeTransition(
      sizeFactor: _sizeFactor,
      axisAlignment: -1.0,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppConstants.spacingSm,
          top: AppConstants.spacingSm,
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
          child: _SubcategoryWrap(
            categories: widget.subcategories,
            ancestors: widget.ancestors,
            messageId: widget.messageId,
            isDisabled: widget.isDisabled,
            expandController: _expandController,
            wasInitiallyExpanded: _wasInitiallyExpanded,
            entranceController: widget.entranceController,
            dfsMap: widget.dfsMap,
            totalItems: widget.totalItems,
            animateItem: widget.animateItem,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _SubcategoryWrap
// ─────────────────────────────────────────────────────────────────────────────

/// Renders depth-1 pills in a [Wrap].
///
/// During the initial entrance, pills use the global entrance controller for
/// their sequential fade+slide (DFS order). For user-triggered expansions
/// (after the entrance completes) pills use the local expand controller with
/// its own stagger.
class _SubcategoryWrap extends StatelessWidget {
  const _SubcategoryWrap({
    required this.categories,
    required this.ancestors,
    required this.messageId,
    required this.isDisabled,
    required this.expandController,
    required this.wasInitiallyExpanded,
    required this.entranceController,
    required this.dfsMap,
    required this.totalItems,
    required this.animateItem,
  });

  final List<Category> categories;
  final List<String> ancestors;
  final String messageId;
  final bool isDisabled;
  final AnimationController expandController;
  final bool wasInitiallyExpanded;
  final AnimationController entranceController;
  final Map<String, int> dfsMap;
  final int totalItems;
  final _AnimateItemFn animateItem;

  @override
  Widget build(BuildContext context) {
    final ChatController controller = context.read<ChatController>();
    final int total = categories.length;
    final bool useEntrance =
        wasInitiallyExpanded && entranceController.value < 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppConstants.spacingXs,
          runSpacing: AppConstants.spacingXs,
          children: List<Widget>.generate(total, (int index) {
            final Category cat = categories[index];
            final String path = controller.buildLabelPath(ancestors, cat.label);
            final CategoryNodeState state = controller.getNodeState(
              messageId,
              path,
              initialSelected: cat.isSelected,
            );
            final Widget pill = CategoryPill(
              emoji: cat.emoji,
              label: cat.label,
              isSelected: state.isSelected,
              isDisabled: isDisabled,
              onTap: () {
                controller.toggleCategorySelection(messageId, path);
              },
              depth: 1,
            );
            // During initial entrance: use DFS-ordered entrance animation.
            // After entrance (user-triggered expand): use local stagger.
            final int? dfsIndex = dfsMap[path];
            if (dfsIndex != null &&
                (useEntrance || entranceController.value < 1.0)) {
              return animateItem(dfsIndex, totalItems, pill);
            }
            // User-triggered expansion stagger
            final double start = (index / total) * 0.4;
            final double end = start + 0.6;
            final Animation<double> itemOpacity = CurvedAnimation(
              parent: expandController,
              curve: Interval(
                start.clamp(0.0, 1.0),
                end.clamp(0.0, 1.0),
                curve: Curves.easeOut,
              ),
            );
            final Animation<Offset> itemSlide =
                Tween<Offset>(
                  begin: const Offset(0, -0.15),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: expandController,
                    curve: Interval(
                      start.clamp(0.0, 1.0),
                      end.clamp(0.0, 1.0),
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                );
            return SlideTransition(
              position: itemSlide,
              child: FadeTransition(opacity: itemOpacity, child: pill),
            );
          }),
        ),
        // Expanded depth-2 groups
        ...List<Widget>.generate(total, (int index) {
          final Category cat = categories[index];
          final String path = controller.buildLabelPath(ancestors, cat.label);
          final CategoryNodeState state = controller.getNodeState(
            messageId,
            path,
            initialSelected: cat.isSelected,
          );
          final bool shouldExpand =
              state.isSelected && cat.subcategories.isNotEmpty;
          return _ExpandableLeafGroup(
            key: ValueKey<String>('leaf_$path'),
            isExpanded: shouldExpand,
            subcategories: cat.subcategories,
            ancestors: [...ancestors, cat.label],
            messageId: messageId,
            isDisabled: isDisabled,
            entranceController: entranceController,
            dfsMap: dfsMap,
            totalItems: totalItems,
            animateItem: animateItem,
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ExpandableLeafGroup
// ─────────────────────────────────────────────────────────────────────────────

/// Expands depth-2 leaf pills in a full-width [Wrap] below a depth-1 parent.
class _ExpandableLeafGroup extends StatefulWidget {
  const _ExpandableLeafGroup({
    super.key,
    required this.isExpanded,
    required this.subcategories,
    required this.ancestors,
    required this.messageId,
    required this.isDisabled,
    required this.entranceController,
    required this.dfsMap,
    required this.totalItems,
    required this.animateItem,
  });

  final bool isExpanded;
  final List<Category> subcategories;
  final List<String> ancestors;
  final String messageId;
  final bool isDisabled;
  final AnimationController entranceController;
  final Map<String, int> dfsMap;
  final int totalItems;
  final _AnimateItemFn animateItem;

  @override
  State<_ExpandableLeafGroup> createState() => _ExpandableLeafGroupState();
}

class _ExpandableLeafGroupState extends State<_ExpandableLeafGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expandController;
  late final Animation<double> _sizeFactor;
  late final bool _wasInitiallyExpanded;

  @override
  void initState() {
    super.initState();
    _wasInitiallyExpanded = widget.isExpanded;
    _expandController = AnimationController(
      vsync: this,
      duration: AppConstants.treeExpandDuration,
      value: widget.isExpanded ? 1.0 : 0.0,
    );
    _sizeFactor = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(_ExpandableLeafGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ChatController controller = context.read<ChatController>();
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final int total = widget.subcategories.length;
    final bool useEntrance =
        _wasInitiallyExpanded && widget.entranceController.value < 1.0;
    return SizeTransition(
      sizeFactor: _sizeFactor,
      axisAlignment: -1.0,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppConstants.spacingSm,
          top: AppConstants.spacingXs,
        ),
        child: Container(
          padding: const EdgeInsets.only(left: AppConstants.spacingSm),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.12),
                width: AppConstants.treeIndentBarWidth,
              ),
            ),
          ),
          child: Wrap(
            spacing: AppConstants.spacingXs,
            runSpacing: AppConstants.spacingXs,
            children: List<Widget>.generate(total, (int index) {
              final Category cat = widget.subcategories[index];
              final String path = controller.buildLabelPath(
                widget.ancestors,
                cat.label,
              );
              final CategoryNodeState state = controller.getNodeState(
                widget.messageId,
                path,
                initialSelected: cat.isSelected,
              );
              final Widget pill = CategoryPill(
                emoji: cat.emoji,
                label: cat.label,
                isSelected: state.isSelected,
                isDisabled: widget.isDisabled,
                onTap: () {
                  controller.toggleCategorySelection(widget.messageId, path);
                },
                depth: 2,
              );
              // During initial entrance: use DFS-ordered animation.
              final int? dfsIndex = widget.dfsMap[path];
              if (dfsIndex != null &&
                  (useEntrance || widget.entranceController.value < 1.0)) {
                return widget.animateItem(dfsIndex, widget.totalItems, pill);
              }
              // User-triggered expansion stagger
              final double start = (index / total) * 0.4;
              final double end = start + 0.6;
              final Animation<double> itemOpacity = CurvedAnimation(
                parent: _expandController,
                curve: Interval(
                  start.clamp(0.0, 1.0),
                  end.clamp(0.0, 1.0),
                  curve: Curves.easeOut,
                ),
              );
              final Animation<Offset> itemSlide =
                  Tween<Offset>(
                    begin: const Offset(0, -0.15),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _expandController,
                      curve: Interval(
                        start.clamp(0.0, 1.0),
                        end.clamp(0.0, 1.0),
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                  );
              return SlideTransition(
                position: itemSlide,
                child: FadeTransition(opacity: itemOpacity, child: pill),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _SubmitTreeButton
// ─────────────────────────────────────────────────────────────────────────────

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
