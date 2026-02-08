import 'package:flutter/material.dart';

import 'package:frontend/model/chat_models.dart';
import 'package:frontend/view/home/widgets/chat/chunks/error_chunk_widget.dart';
import 'package:frontend/view/home/widgets/chat/chunks/retailer_call_chunk_widget.dart';
import 'package:frontend/view/home/widgets/chat/chunks/text_chunk_widget.dart';
import 'package:frontend/view/home/widgets/chat/chunks/text_form_chunk_widget.dart';
import 'package:frontend/view/home/widgets/chat/chunks/tree_chunk_widget.dart';

/// Delegates rendering to the correct chunk widget based on type.
class ChunkRenderer extends StatelessWidget {
  const ChunkRenderer({
    super.key,
    required this.chunk,
    required this.messageId,
    required this.isDisabled,
    this.onChunkReady,
    this.isLastInMessage = true,
  });

  final OutputItemBase chunk;
  final String messageId;
  final bool isDisabled;
  final VoidCallback? onChunkReady;
  final bool isLastInMessage;

  @override
  Widget build(BuildContext context) {
    if (chunk is TextChunk) {
      return TextChunkWidget(
        chunk: chunk as TextChunk,
        onTypingComplete: onChunkReady,
      );
    }
    if (chunk is TreeChunk) {
      return TreeChunkWidget(
        chunk: chunk as TreeChunk,
        messageId: messageId,
        isDisabled: isDisabled,
      );
    }
    if (chunk is TextFormChunk) {
      return TextFormChunkWidget(
        chunk: chunk as TextFormChunk,
        messageId: messageId,
        isDisabled: isDisabled,
        isPinned: false,
      );
    }
    if (chunk is ErrorOutput) {
      return ErrorChunkWidget(error: chunk as ErrorOutput);
    }
    if (chunk is RetailerCallChunk) {
      return RetailerCallChunkWidget(
        chunk: chunk as RetailerCallChunk,
        isLastInMessage: isLastInMessage,
      );
    }
    return const SizedBox.shrink();
  }
}
