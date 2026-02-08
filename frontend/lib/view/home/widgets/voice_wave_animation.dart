import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:frontend/config/app_constants.dart';

/// Animated voice-wave bars driven by real microphone amplitude.
///
/// Always visible: when [amplitude] is 0 the bars form a flat horizontal line.
/// As [amplitude] rises towards 1.0 the bars oscillate with an organic,
/// multi-frequency wave that reacts proportionally to voice loudness.
class VoiceWaveAnimation extends StatefulWidget {
  /// Normalised microphone amplitude from 0.0 (silent / idle) to 1.0 (loud).
  final double amplitude;

  const VoiceWaveAnimation({
    required this.amplitude,
    super.key,
  });

  @override
  State<VoiceWaveAnimation> createState() => _VoiceWaveAnimationState();
}

class _VoiceWaveAnimationState extends State<VoiceWaveAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Smoothly interpolated intensity that tracks [widget.amplitude].
  double _intensity = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _controller.addListener(_onTick);
    _controller.repeat();
  }

  void _onTick() {
    if (!mounted) return;
    // Smoothly chase the target amplitude each frame.
    final double target = widget.amplitude;
    if ((_intensity - target).abs() > 0.001) {
      _intensity = _intensity + (target - _intensity) * 0.15;
    } else {
      _intensity = target;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  /// Computes an organic bar height by layering three sine waves at different
  /// frequencies, shaped by a bell-curve envelope, and scaled by [_intensity].
  double _computeBarHeight(int index) {
    final double t = _controller.value * 2 * math.pi;
    final double normalizedIndex =
        index / (AppConstants.waveBarCount - 1); // 0..1
    // Three overlapping sine waves for natural voice-like motion.
    final double wave1 = math.sin(t * 1.0 + normalizedIndex * 6.0);
    final double wave2 = 0.6 * math.sin(t * 2.3 + normalizedIndex * 4.0);
    final double wave3 = 0.3 * math.sin(t * 3.7 + normalizedIndex * 8.0);
    // Combine and normalise to 0..1 range.
    final double combined = (wave1 + wave2 + wave3 + 1.9) / 3.8;
    // Bell-curve envelope: centre bars reach full height, edges stay shorter.
    final double centreDistance = (normalizedIndex - 0.5).abs();
    final double envelope = (1.0 - centreDistance * 1.2).clamp(0.15, 1.0);
    final double activeHeight = AppConstants.waveBarIdleHeight +
        (AppConstants.waveBarMaxHeight - AppConstants.waveBarIdleHeight) *
            combined *
            envelope;
    // Lerp between flat idle height and computed active height.
    return AppConstants.waveBarIdleHeight +
        (activeHeight - AppConstants.waveBarIdleHeight) * _intensity;
  }

  @override
  Widget build(BuildContext context) {
    final double opacity = AppConstants.waveBarIdleOpacity +
        (AppConstants.waveBarActiveOpacity - AppConstants.waveBarIdleOpacity) *
            _intensity;
    return SizedBox(
      height: AppConstants.waveBarMaxHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(AppConstants.waveBarCount, (int index) {
          final double height = _computeBarHeight(index);
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.waveBarSpacing / 2,
            ),
            child: Container(
              width: AppConstants.waveBarWidth,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: opacity),
                borderRadius: BorderRadius.circular(
                  AppConstants.waveBarWidth / 2,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
