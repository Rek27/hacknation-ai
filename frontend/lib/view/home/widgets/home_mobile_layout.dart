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
import 'package:frontend/service/agent_api.dart';
import 'package:frontend/model/chat_message.dart';
import 'package:frontend/model/chat_models.dart';

/// Mobile layout: pre-call screen with "Start call", then Apple-style call UI
/// with assistant name, hang-up button, compact input/chips, and cart overlay.
class HomeMobileLayout extends StatelessWidget {
  const HomeMobileLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController homeController = context.watch<HomeController>();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ChatController>(
          create: (_) => ChatController(
            chatService: RealChatService(
              homeController.api,
              homeController.sessionId,
            ),
          ),
        ),
        ChangeNotifierProvider<CartController>(
          create: (_) => CartController(),
        ),
        ChangeNotifierProvider<MicrophoneController>(
          create: (_) => MicrophoneController(),
        ),
      ],
      child: const _MobileCallBody(),
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
    return _isInCall ? _InCallView(onOpenCart: _openCart, onEndCall: _onEndCall) : _PreCallView(onStartCall: _onStartCall, onOpenCart: _openCart);
  }

  void _onStartCall() {
    context.read<MicrophoneController>().startListening();
    setState(() => _isInCall = true);
  }

  void _onEndCall() {
    context.read<MicrophoneController>().stopListening();
    context.read<ChatController>().clearConversation();
    setState(() => _isInCall = false);
  }
}

/// Pre-call screen: assistant info and "Start call" button.
class _PreCallView extends StatelessWidget {
  const _PreCallView({
    required this.onStartCall,
    required this.onOpenCart,
  });

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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              'Tap to start a call with your assistant',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
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
        child: GestureDetector(
          onTap: onStartCall,
          child: Container(
            width: AppConstants.callUiEndButtonSize,
            height: AppConstants.callUiEndButtonSize,
            decoration: BoxDecoration(
              color: const Color(0xFF34C759),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF34C759).withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.call_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
      ),
    );
  }
}

/// In-call view: current call UI with controls and input.
class _InCallView extends StatelessWidget {
  const _InCallView({
    required this.onOpenCart,
    required this.onEndCall,
  });

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
            Color(0xFF1C1C1E),
            Color(0xFF2C2C2E),
            Color(0xFF000000),
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
              minimumSize: const Size(44, 44),
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
    final ChatController chatController = context.watch<ChatController>();
    final MicrophoneController micController = context.watch<MicrophoneController>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TalkingAvatar(
              isTalking: chatController.isLoading,
              size: AppConstants.callUiAvatarSize,
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              AppConstants.callUiAssistantName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              chatController.isLoading ? 'Listening...' : 'Say something',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            VoiceWaveAnimation(amplitude: micController.amplitude),
            const SizedBox(height: AppConstants.spacingLg),
            _LiveTranscriptStrip(chatController: chatController),
          ],
        ),
      ),
    );
  }
}

class _LiveTranscriptStrip extends StatelessWidget {
  const _LiveTranscriptStrip({required this.chatController});

  final ChatController chatController;

  @override
  Widget build(BuildContext context) {
    final String? snippet = _lastAgentTextSnippet(chatController);
    if (snippet == null || snippet.isEmpty) return const SizedBox.shrink();
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
          snippet,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String? _lastAgentTextSnippet(ChatController controller) {
    for (int i = controller.messages.length - 1; i >= 0; i--) {
      final msg = controller.messages[i];
      if (msg.sender != ChatMessageSender.agent) continue;
      for (final chunk in msg.chunks) {
        if (chunk is TextChunk && chunk.content.trim().isNotEmpty) {
          final text = chunk.content.trim();
          return text.length > 120 ? '${text.substring(0, 120)}...' : text;
        }
      }
    }
    return null;
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
        children: [
          _CallControlRow(onEndCall: onEndCall),
        ],
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
        _PlaceholderCallButton(icon: Icons.mic_off_rounded, label: 'Mute'),
        const SizedBox(width: AppConstants.spacingXl),
        _EndCallButton(onPressed: onEndCall),
        const SizedBox(width: AppConstants.spacingXl),
        _PlaceholderCallButton(icon: Icons.volume_up_rounded, label: 'Speaker'),
      ],
    );
  }
}

class _PlaceholderCallButton extends StatelessWidget {
  const _PlaceholderCallButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: () {},
          color: Colors.white,
          iconSize: AppConstants.iconSizeSm,
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
          ),
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
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
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: AppConstants.callUiEndButtonSize,
          height: AppConstants.callUiEndButtonSize,
          decoration: const BoxDecoration(
            color: Color(0xFFEB2D2D),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x4DEB2D2D),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.call_end_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }
}

