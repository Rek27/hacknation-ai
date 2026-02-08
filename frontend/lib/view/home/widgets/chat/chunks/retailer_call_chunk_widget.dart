import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:frontend/config/app_constants.dart';
import 'package:frontend/model/chat_models.dart';

/// Reassurance sentences shown while the retailer call is in progress.
const List<String> _retailerCallReassuranceSentences = [
  'Negotiating better prices for you',
  'Telling the retailer how important your purchase is',
  'Working on the best deal for your order',
  'Discussing delivery and discounts',
  'Almost there — wrapping up with retailers',
];

/// Renders a retailer call chunk: phone icon with rotating sentences when the
/// call is in progress, or call-ended icon with final sentence when finished.
class RetailerCallChunkWidget extends StatefulWidget {
  const RetailerCallChunkWidget({
    super.key,
    required this.chunk,
    required this.isLastInMessage,
  });

  final RetailerCallChunk chunk;
  final bool isLastInMessage;

  @override
  State<RetailerCallChunkWidget> createState() =>
      _RetailerCallChunkWidgetState();
}

class _RetailerCallChunkWidgetState extends State<RetailerCallChunkWidget> {
  late int _sentenceIndex;

  static final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _sentenceIndex = _random.nextInt(_retailerCallReassuranceSentences.length);
    if (widget.isLastInMessage) {
      _startRotation();
    }
  }

  @override
  void didUpdateWidget(RetailerCallChunkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLastInMessage && !oldWidget.isLastInMessage) {
      _startRotation();
    } else if (!widget.isLastInMessage && oldWidget.isLastInMessage) {
      _stopRotation();
    }
  }

  @override
  void dispose() {
    _stopRotation();
    super.dispose();
  }

  void _startRotation() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
    _rotationTimer = _createRotationTimer();
  }

  void _stopRotation() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
  }

  Timer? _rotationTimer;

  Timer _createRotationTimer() {
    return Timer(AppConstants.retailerCallSentenceRotationDuration, () {
      if (!mounted || !widget.isLastInMessage) return;
      final int length = _retailerCallReassuranceSentences.length;
      int next = _random.nextInt(length);
      if (length > 1 && next == _sentenceIndex) {
        next = (next + 1) % length;
      }
      setState(() {
        _sentenceIndex = next;
      });
      _rotationTimer = _createRotationTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool inProgress = widget.isLastInMessage;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          inProgress ? Icons.phone_in_talk_rounded : Icons.call_end_rounded,
          size: AppConstants.iconSizeMd,
          color: inProgress
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
        SizedBox(height: AppConstants.spacingSm),
        if (inProgress)
          AnimatedSwitcher(
            duration: AppConstants.durationMedium,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              _retailerCallReassuranceSentences[_sentenceIndex],
              key: ValueKey<int>(_sentenceIndex),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          Text(
            'All the negotiations are finished!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}
