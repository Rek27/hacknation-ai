import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/config/app_constants.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:frontend/view/home/widgets/chat/chat_controller.dart';
import 'package:frontend/view/home/widgets/chat/chunks/category_tile.dart';

/// Renders a TreeChunk as a grid of selectable/expandable categories.
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
    // Watch the controller so we rebuild when selections change
    context.watch<ChatController>();
    return Container(
      margin: const EdgeInsets.only(top: AppConstants.spacingSm),
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryLevel(context, chunk.category.subcategories, <String>[
            chunk.category.label,
          ]),
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
    );
  }

  /// Builds a level of the tree. Each category is wrapped in its own column
  /// so that subcategories expand directly below their parent tile.
  Widget _buildCategoryLevel(
    BuildContext context,
    List<Category> categories,
    List<String> ancestors,
  ) {
    final ChatController controller = context.read<ChatController>();
    return Wrap(
      spacing: AppConstants.spacingSm,
      runSpacing: AppConstants.spacingSm,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: categories.map((Category cat) {
        final String path = controller.buildLabelPath(ancestors, cat.label);
        final CategoryNodeState state = controller.getNodeState(
          messageId,
          path,
        );
        final bool shouldExpand =
            state.isSelected && cat.subcategories.isNotEmpty;
        return _CategoryColumn(
          tile: CategoryTile(
            emoji: cat.emoji,
            label: cat.label,
            isSelected: state.isSelected,
            isDisabled: isDisabled,
            onTap: () {
              controller.toggleCategorySelection(messageId, path);
            },
          ),
          isExpanded: shouldExpand,
          subcategories: Padding(
            padding: const EdgeInsets.only(
              left: AppConstants.spacingSm,
              top: AppConstants.spacingSm,
              bottom: AppConstants.spacingSm,
            ),
            child: _buildCategoryLevel(context, cat.subcategories, [
              ...ancestors,
              cat.label,
            ]),
          ),
        );
      }).toList(),
    );
  }
}

/// Pairs a category tile with its subcategories in a vertical column.
/// Subcategories animate in/out directly below the parent tile.
class _CategoryColumn extends StatelessWidget {
  const _CategoryColumn({
    required this.tile,
    required this.isExpanded,
    required this.subcategories,
  });

  final Widget tile;
  final bool isExpanded;
  final Widget subcategories;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tile,
          if (isExpanded)
            Container(
              margin: const EdgeInsets.only(top: AppConstants.spacingXs),
              padding: const EdgeInsets.only(left: AppConstants.spacingXs),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
              ),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: 1.0,
                child: subcategories,
              ),
            ),
        ],
      ),
    );
  }
}

/// Submit button for tree selections.
class _SubmitTreeButton extends StatefulWidget {
  const _SubmitTreeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_SubmitTreeButton> createState() => _SubmitTreeButtonState();
}

class _SubmitTreeButtonState extends State<_SubmitTreeButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: ElevatedButton.icon(
            onPressed: widget.onPressed,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Submit Selection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isHovered
                  ? colorScheme.primary
                  : colorScheme.primary.withValues(alpha: 0.9),
              foregroundColor: colorScheme.onPrimary,
              elevation: _isHovered ? 2 : 0,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingLg,
                vertical: AppConstants.spacingMd,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
