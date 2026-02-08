import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/home_controller.dart';
import 'package:frontend/view/home/widgets/chat/chat_controller.dart';
import 'package:frontend/view/home/widgets/cart/cart_controller.dart';
import 'package:frontend/view/home/widgets/cart/cart_sheet.dart';
import 'package:frontend/view/home/widgets/talking_avatar.dart';
import 'package:frontend/view/home/widgets/microphone_controller.dart';
import 'package:frontend/view/home/widgets/voice_wave_animation.dart';
import 'package:frontend/view/home/widgets/voice_controller.dart';
import 'package:frontend/service/agent_api.dart';

/// Mobile layout: pre-call screen with "Start call", then Apple-style call UI
/// with assistant name, hang-up button, compact input/chips, and cart overlay.
class HomeMobileLayout extends StatelessWidget {
  const HomeMobileLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController homeController = context.watch<HomeController>();
    // CartController must be created first so ChatController can reference it.
    return ChangeNotifierProvider<CartController>(
      create: (_) => CartController(),
      child: Builder(
        builder: (cartContext) {
          final CartController cartController = cartContext
              .read<CartController>();
          return MultiProvider(
            providers: [
              ChangeNotifierProvider<ChatController>(
                create: (_) => ChatController(
                  chatService: RealChatService(
                    homeController.api,
                    homeController.sessionId,
                  ),
                  cartController: cartController,
                ),
              ),
              ChangeNotifierProvider<MicrophoneController>(
                create: (_) => MicrophoneController(),
              ),
              ChangeNotifierProvider<VoiceController>(
                create: (_) => VoiceController(
                  api: homeController.api,
                  sessionId: homeController.sessionId,
                ),
              ),
            ],
            child: const _MobileCallBody(),
          );
        },
      ),
    );
  }
}

class _MobileCallBody extends StatefulWidget {
  const _MobileCallBody();

  @override
  State<_MobileCallBody> createState() => _MobileCallBodyState();
}

class _MobileCallBodyState extends State<_MobileCallBody> {
  bool _isInCall = false;

  void _openCart(BuildContext context) {
    final CartController cartController = context.read<CartController>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.9,
        child: ChangeNotifierProvider<CartController>.value(
          value: cartController,
          child: const CartSheet(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isInCall
        ? _InCallView(onOpenCart: _openCart, onEndCall: _onEndCall)
        : _PreCallView(onStartCall: _onStartCall, onOpenCart: _openCart);
  }

  void _onStartCall() async {
    context.read<MicrophoneController>().startListening();
    setState(() => _isInCall = true);
    // Start the voice session with the hardcoded greeting
    await context.read<VoiceController>().startVoiceSession();
  }

  void _onEndCall() async {
    context.read<MicrophoneController>().stopListening();
    context.read<ChatController>().clearConversation();
    await context.read<VoiceController>().endSession();
    setState(() => _isInCall = false);
  }
}

/// Pre-call screen: assistant info and "Start call" button.
class _PreCallView extends StatelessWidget {
  const _PreCallView({required this.onStartCall, required this.onOpenCart});

  final VoidCallback onStartCall;
  final void Function(BuildContext context) onOpenCart;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _CallStyleBackground(),
        SafeArea(
          child: Column(
            children: [
              _CallTopBar(onOpenCart: () => onOpenCart(context)),
              const Expanded(child: _PreCallCenterContent()),
              _PreCallBottomButton(onStartCall: onStartCall),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreCallCenterContent extends StatelessWidget {
  const _PreCallCenterContent();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TalkingAvatar(
              isTalking: false,
              size: AppConstants.callUiAvatarSize,
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              AppConstants.callUiAssistantName,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              'Tap to start a call with your assistant',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreCallBottomButton extends StatelessWidget {
  const _PreCallBottomButton({required this.onStartCall});

  final VoidCallback onStartCall;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingMd,
        AppConstants.spacingLg,
        AppConstants.spacingXl,
      ),
      child: Semantics(
        label: 'Start call',
        button: true,
        child: Material(
          color: AppConstants.callAccept,
          shape: const CircleBorder(),
          elevation: AppConstants.elevationSm,
          shadowColor: AppConstants.callAccept.withValues(alpha: 0.4),
          child: InkWell(
            onTap: onStartCall,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: AppConstants.callUiEndButtonSize,
              height: AppConstants.callUiEndButtonSize,
              child: const Icon(
                Icons.call_rounded,
                color: Colors.white,
                size: AppConstants.callUiActionIconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// In-call view: current call UI with controls and input.
class _InCallView extends StatelessWidget {
  const _InCallView({required this.onOpenCart, required this.onEndCall});

  final void Function(BuildContext context) onOpenCart;
  final VoidCallback onEndCall;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _CallStyleBackground(),
        SafeArea(
          child: Column(
            children: [
              _CallTopBar(onOpenCart: () => onOpenCart(context)),
              const Expanded(child: _CallCenterContent()),
              _CallBottomControls(onEndCall: onEndCall),
            ],
          ),
        ),
      ],
    );
  }
}

class _CallStyleBackground extends StatelessWidget {
  const _CallStyleBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppConstants.callBgTop,
            AppConstants.callBgMid,
            AppConstants.callBgBottom,
          ],
        ),
      ),
    );
  }
}

class _CallTopBar extends StatelessWidget {
  const _CallTopBar({required this.onOpenCart});

  final VoidCallback onOpenCart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: onOpenCart,
            tooltip: 'Cart',
            color: Colors.white,
            iconSize: AppConstants.iconSizeSm,
            style: IconButton.styleFrom(
              minimumSize: const Size(
                AppConstants.callUiTouchTarget,
                AppConstants.callUiTouchTarget,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallCenterContent extends StatelessWidget {
  const _CallCenterContent();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final VoiceController voiceController = context.watch<VoiceController>();
    final MicrophoneController micController = context
        .watch<MicrophoneController>();

    // Show wave animation when user is speaking (recording)
    // or when assistant is thinking (loading but not playing)
    final bool showWave =
        voiceController.isRecording ||
        (voiceController.isLoading && !voiceController.isPlaying);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TalkingAvatar(
              isTalking: voiceController.isTalking,
              size: AppConstants.callUiAvatarSize,
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              AppConstants.callUiAssistantName,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              _getStatusText(voiceController),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            VoiceWaveAnimation(
              amplitude: showWave ? micController.amplitude : 0.0,
            ),
            const SizedBox(height: AppConstants.spacingLg),
            _LiveTranscriptStrip(voiceController: voiceController),
          ],
        ),
      ),
    );
  }

  String _getStatusText(VoiceController controller) {
    if (controller.isRecording) return 'Listening... (speak now)';
    if (controller.isLoading) return 'Processing your request...';
    if (controller.isPlaying) return 'Speaking...';
    if (controller.error != null) return 'Error occurred';
    return 'Ready to listen';
  }
}

class _LiveTranscriptStrip extends StatelessWidget {
  const _LiveTranscriptStrip({required this.voiceController});

  final VoiceController voiceController;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String snippet = voiceController.lastAssistantText.trim();
    if (snippet.isEmpty) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingSm,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        child: Text(
          snippet.length > 120 ? '${snippet.substring(0, 120)}...' : snippet,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _CallBottomControls extends StatelessWidget {
  const _CallBottomControls({required this.onEndCall});

  final VoidCallback onEndCall;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingMd,
        AppConstants.spacingLg,
        AppConstants.spacingXl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [_CallControlRow(onEndCall: onEndCall)],
      ),
    );
  }
}

class _CallControlRow extends StatelessWidget {
  const _CallControlRow({required this.onEndCall});

  final VoidCallback onEndCall;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _MicrophoneButton(),
        const SizedBox(width: AppConstants.spacingXl),
        _EndCallButton(onPressed: onEndCall),
        const SizedBox(width: AppConstants.spacingXl),
        _PlaceholderCallButton(icon: Icons.volume_up_rounded, label: 'Speaker'),
      ],
    );
  }
}

class _MicrophoneButton extends StatelessWidget {
  const _MicrophoneButton();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final VoiceController voiceController = context.watch<VoiceController>();

    final bool isRecording = voiceController.isRecording;
    final bool isDisabled =
        voiceController.isLoading || voiceController.isPlaying;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: isRecording && !isDisabled ? () => _onMicTap(context) : null,
          child: Container(
            width: AppConstants.callUiTouchTarget,
            height: AppConstants.callUiTouchTarget,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRecording
                  ? AppConstants.callReject.withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
            child: Icon(
              isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: isDisabled
                  ? Colors.white.withValues(alpha: 0.3)
                  : (isRecording ? AppConstants.callReject : Colors.white),
              size: AppConstants.iconSizeSm,
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Text(
          isRecording ? 'Tap to cancel' : 'Auto listening',
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  void _onMicTap(BuildContext context) {
    // Allow manual cancellation during recording
    context.read<VoiceController>().cancelRecording();
  }
}

class _PlaceholderCallButton extends StatelessWidget {
  const _PlaceholderCallButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: () {},
          color: Colors.white,
          iconSize: AppConstants.iconSizeSm,
          style: IconButton.styleFrom(
            minimumSize: const Size(
              AppConstants.callUiTouchTarget,
              AppConstants.callUiTouchTarget,
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _EndCallButton extends StatelessWidget {
  const _EndCallButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'End call',
      button: true,
      child: Material(
        color: AppConstants.callReject,
        shape: const CircleBorder(),
        elevation: AppConstants.elevationSm,
        shadowColor: AppConstants.callReject.withValues(alpha: 0.4),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: AppConstants.callUiEndButtonSize,
            height: AppConstants.callUiEndButtonSize,
            child: const Icon(
              Icons.call_end_rounded,
              color: Colors.white,
              size: AppConstants.callUiActionIconSize,
            ),
          ),
        ),
      ),
    );
  }
}
