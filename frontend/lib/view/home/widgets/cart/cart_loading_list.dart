import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:rive/rive.dart' as rive;

const String _cartLoadingAssetPath = 'assets/11929-22748-simple-loading.riv';

const List<String> _loadingSentences = [
  'Searching retailers for the best deals...',
  'Comparing prices across stores...',
  'Finding the freshest products for you...',
  'Putting together your perfect cart...',
  'Checking availability in your area...',
  'Hunting down the best offers...',
  'Almost there, curating your selections...',
  'Making sure you get the best value...',
];

/// Centered Rive loading animation with rotating reassurance sentences
/// shown while the cart is being generated.
class CartLoadingList extends StatefulWidget {
  const CartLoadingList({super.key});

  @override
  State<CartLoadingList> createState() => _CartLoadingListState();
}

class _CartLoadingListState extends State<CartLoadingList> {
  rive.File? _riveFile;
  rive.RiveWidgetController? _controller;
  bool _isRiveInitialized = false;
  int _currentSentenceIndex = 0;
  late final Timer _sentenceTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initRive();
    _currentSentenceIndex = _random.nextInt(_loadingSentences.length);
    _sentenceTimer = Timer.periodic(
      AppConstants.cartLoadingSentenceRotationDuration,
      (_) => _rotateSentence(),
    );
  }

  Future<void> _initRive() async {
    try {
      _riveFile = await rive.File.asset(
        _cartLoadingAssetPath,
        riveFactory: rive.Factory.rive,
      );
      if (_riveFile == null) return;
      _controller = rive.RiveWidgetController(
        _riveFile!,
        stateMachineSelector: const rive.StateMachineAtIndex(0),
      );
      if (mounted) {
        setState(() => _isRiveInitialized = true);
      }
    } catch (e) {
      print('CartLoadingList._initRive error: $e');
    }
  }

  void _rotateSentence() {
    if (!mounted) return;
    int nextIndex;
    do {
      nextIndex = _random.nextInt(_loadingSentences.length);
    } while (nextIndex == _currentSentenceIndex &&
        _loadingSentences.length > 1);
    setState(() => _currentSentenceIndex = nextIndex);
  }

  @override
  void dispose() {
    _sentenceTimer.cancel();
    _controller?.dispose();
    _riveFile?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CartLoadingRiveAnimation(
              isInitialized: _isRiveInitialized,
              controller: _controller,
              theme: theme,
            ),
            const SizedBox(height: AppConstants.spacingLg),
            _CartLoadingRotatingText(
              sentence: _loadingSentences[_currentSentenceIndex],
              sentenceIndex: _currentSentenceIndex,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays the Rive animation or a fallback spinner while loading.
class _CartLoadingRiveAnimation extends StatelessWidget {
  const _CartLoadingRiveAnimation({
    required this.isInitialized,
    required this.controller,
    required this.theme,
  });

  final bool isInitialized;
  final rive.RiveWidgetController? controller;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (!isInitialized || controller == null) {
      return SizedBox(
        width: AppConstants.cartLoadingAnimationSize,
        height: AppConstants.cartLoadingAnimationSize,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }
    return SizedBox(
      width: AppConstants.cartLoadingAnimationSize,
      height: AppConstants.cartLoadingAnimationSize,
      child: rive.RiveWidget(controller: controller!, fit: rive.Fit.contain),
    );
  }
}

/// Cross-fades between rotating reassurance sentences.
class _CartLoadingRotatingText extends StatelessWidget {
  const _CartLoadingRotatingText({
    required this.sentence,
    required this.sentenceIndex,
    required this.theme,
  });

  final String sentence;
  final int sentenceIndex;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppConstants.durationSlow,
      child: Text(
        sentence,
        key: ValueKey<int>(sentenceIndex),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
