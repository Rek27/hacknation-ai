import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import 'package:frontend/config/app_constants.dart';
import 'package:frontend/model/chat_models.dart';

/// Asset path for the Rive calling animation.
const String _callingAnimationAssetPath =
    'assets/2569-5232-calling-animation.riv';

/// Reassurance sentences shown while the retailer call is in progress.
const List<String> _retailerCallReassuranceSentences = [
  'Negotiating better prices for you',
  'Telling the retailer how important your purchase is',
  'Working on the best deal for your order',
  'Discussing delivery and discounts',
  'Almost there — wrapping up with retailers',
];

/// Renders a retailer call chunk: Rive calling animation with rotating
/// sentences when the call is in progress, or call-ended icon with final
/// sentence when finished. Content is centered inside a neutral tile.
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
  Timer? _rotationTimer;
  rive.File? _riveFile;
  rive.RiveWidgetController? _riveController;
  bool _isRiveInitialized = false;

  static final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _sentenceIndex = _random.nextInt(_retailerCallReassuranceSentences.length);
    if (widget.isLastInMessage) {
      _startRotation();
      _initRive();
    }
  }

  @override
  void didUpdateWidget(RetailerCallChunkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLastInMessage && !oldWidget.isLastInMessage) {
      _startRotation();
      _initRive();
    } else if (!widget.isLastInMessage && oldWidget.isLastInMessage) {
      _stopRotation();
      _disposeRive();
    }
  }

  @override
  void dispose() {
    _stopRotation();
    _disposeRive();
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

  Future<void> _initRive() async {
    try {
      _riveFile = await rive.File.asset(
        _callingAnimationAssetPath,
        riveFactory: rive.Factory.rive,
      );
      if (_riveFile == null) return;
      _riveController = rive.RiveWidgetController(_riveFile!);
      if (mounted) {
        setState(() => _isRiveInitialized = true);
      }
    } catch (e) {
      print('RetailerCallChunkWidget._initRive error: $e');
    }
  }

  void _disposeRive() {
    _riveController?.dispose();
    _riveController = null;
    _riveFile?.dispose();
    _riveFile = null;
    _isRiveInitialized = false;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool inProgress = widget.isLastInMessage;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppConstants.spacingSm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: AppConstants.retailerCallAnimationSize,
            child: Center(
              child: inProgress
                  ? _buildCallingAnimation()
                  : _buildCallEndedIcon(colorScheme),
            ),
          ),
          SizedBox(height: AppConstants.spacingSm),
          if (inProgress)
            _buildRotatingSentence(theme, colorScheme)
          else
            _buildFinishedSentence(theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildCallingAnimation() {
    if (!_isRiveInitialized || _riveController == null) {
      return SizedBox(
        width: AppConstants.retailerCallAnimationSize,
        height: AppConstants.retailerCallAnimationSize,
      );
    }
    return SizedBox(
      width: AppConstants.retailerCallAnimationSize,
      height: AppConstants.retailerCallAnimationSize,
      child: rive.RiveWidget(
        controller: _riveController!,
        fit: rive.Fit.contain,
      ),
    );
  }

  Widget _buildCallEndedIcon(ColorScheme colorScheme) {
    return Icon(
      Icons.call_end_rounded,
      size: AppConstants.iconSizeMd,
      color: colorScheme.onSurfaceVariant,
    );
  }

  Widget _buildRotatingSentence(ThemeData theme, ColorScheme colorScheme) {
    return AnimatedSwitcher(
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
    );
  }

  Widget _buildFinishedSentence(ThemeData theme, ColorScheme colorScheme) {
    return Text(
      'All the negotiations are finished!',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      textAlign: TextAlign.center,
    );
  }
}
