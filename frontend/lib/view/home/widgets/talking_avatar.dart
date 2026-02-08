import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

/// Animated Rive face avatar that blinks while idle and talks when the AI
/// speaks.  Uses a state machine driven approach – the widget probes the
/// default state machine for a boolean input that controls talking and toggles
/// it in response to [isTalking].
///
/// Falls back to a simple [CircleAvatar] if the Rive file fails to load.
class TalkingAvatar extends StatefulWidget {
  final bool isTalking;
  final double size;

  const TalkingAvatar({
    required this.isTalking,
    required this.size,
    super.key,
  });

  @override
  State<TalkingAvatar> createState() => _TalkingAvatarState();
}

class _TalkingAvatarState extends State<TalkingAvatar> {
  static const String _assetPath = 'assets/wave_hear_talk.riv';

  /// Common boolean input names that Rive files use for a talking state.
  static const List<String> _talkInputNames = [
    'Talk',
    'talk',
    'isTalking',
    'Talking',
    'talking',
    'Speak',
    'speak',
    'isSpeaking',
  ];

  rive.File? _riveFile;
  rive.RiveWidgetController? _controller;
  rive.BooleanInput? _talkInput;
  rive.TriggerInput? _talkTrigger;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initRive();
  }

  Future<void> _initRive() async {
    try {
      _riveFile = await rive.File.asset(
        _assetPath,
        riveFactory: rive.Factory.rive,
      );
      if (_riveFile == null) return;
      _controller = rive.RiveWidgetController(_riveFile!);
      _discoverTalkInput();
      _applyTalkingState(widget.isTalking);
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      print('TalkingAvatar._initRive error: $e');
    }
  }

  /// Probe the state machine for a boolean (or trigger) input that controls
  /// the talking animation. Tries several conventional names.
  void _discoverTalkInput() {
    if (_controller == null) return;
    final rive.StateMachine stateMachine = _controller!.stateMachine;
    for (final String name in _talkInputNames) {
      try {
        final rive.BooleanInput? input = stateMachine.boolean(name);
        if (input != null) {
          _talkInput = input;
          return;
        }
      } catch (_) {
        // Input not found – continue probing.
      }
    }
    // If no boolean found, try a trigger instead.
    for (final String name in _talkInputNames) {
      try {
        final rive.TriggerInput? trigger = stateMachine.trigger(name);
        if (trigger != null) {
          _talkTrigger = trigger;
          return;
        }
      } catch (_) {
        // Input not found – continue probing.
      }
    }
  }

  void _applyTalkingState(bool isTalking) {
    if (_talkInput != null) {
      _talkInput!.value = isTalking;
    } else if (_talkTrigger != null && isTalking) {
      _talkTrigger!.fire();
    }
  }

  @override
  void didUpdateWidget(TalkingAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTalking != oldWidget.isTalking) {
      _applyTalkingState(widget.isTalking);
    }
  }

  @override
  void dispose() {
    _talkInput?.dispose();
    _talkTrigger?.dispose();
    _controller?.dispose();
    _riveFile?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return _buildFallbackAvatar();
    }
    // Shift content upward so the face (top portion of the artboard) is
    // centered within the circular clip, hiding the body/shoulders.
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipOval(
        child: Transform.translate(
          offset: Offset(0, -widget.size * 0.08),
          child: rive.RiveWidget(
            controller: _controller!,
            fit: rive.Fit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    return CircleAvatar(
      radius: widget.size / 2,
      backgroundColor: Colors.white12,
      child: Icon(
        Icons.person_rounded,
        size: widget.size * 0.6,
        color: Colors.white70,
      ),
    );
  }
}
