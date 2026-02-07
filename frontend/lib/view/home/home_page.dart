import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../service/agent_api.dart';
import '../../service/api_client.dart';
import 'home_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // NOTE:
    // - On Android emulator, "localhost" points to the emulator itself, not your PC.
    //   Use 10.0.2.2 to reach the host machine's localhost.
    // - You can override via: flutter run --dart-define=API_BASE_URL=http://<host>:8000
    const configuredBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );
    final baseUrl =
        configuredBaseUrl.isNotEmpty
            ? configuredBaseUrl
            : (Platform.isAndroid
                ? 'http://10.0.2.2:8000'
                : 'http://localhost:8000');

    return ChangeNotifierProvider<HomeController>(
      create: (_) => HomeController(
        api: AgentApi(ApiClient(baseUrl: baseUrl)),
        sessionId: 'session-${DateTime.now().millisecondsSinceEpoch}',
      )..loadInitial(),
      child: _HomeView(baseUrl: baseUrl),
    );
  }
}

class _HomeView extends StatefulWidget {
  final String baseUrl;

  const _HomeView({required this.baseUrl});

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();
    final health = controller.health;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Agent Chat'),
        backgroundColor: Colors.deepPurple,
        actions: [
          Tooltip(
            message: 'API: ${widget.baseUrl}',
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  'API',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
          Icon(
            health?.status == 'healthy' ? Icons.check_circle : Icons.error,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          if (health != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  'Chunks: ${health.documentsCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (controller.errorMessage != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                controller.errorMessage!,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          Expanded(
            child: Row(
              children: [
                _buildSidebar(context, controller),
                Expanded(child: _buildChatArea(context, controller)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, HomeController c) {
    return Container(
      width: 260,
      color: Colors.grey.shade100,
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Documents',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: c.refreshDocuments,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload'),
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['txt', 'pdf'],
                );
                if (result != null && result.files.single.path != null) {
                  await c.upload(File(result.files.single.path!));
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: c.loadingDocs
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: c.documents.length,
                    itemBuilder: (context, index) {
                      final doc = c.documents[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          doc.filename,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('${doc.chunks} chunks'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => c.deleteDoc(doc.filename),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea(BuildContext context, HomeController c) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.grey.shade200,
            child: ListView.builder(
              controller: _scrollController,
              itemCount: c.chatItems.length,
              itemBuilder: (context, index) {
                final item = c.chatItems[index];
                switch (item.type) {
                  case ChatItemType.user:
                    return _chatBubble(isUser: true, child: Text(item.text));
                  case ChatItemType.assistant:
                    return _chatBubble(isUser: false, child: Text(item.text));
                  case ChatItemType.tool:
                    return _chatBubble(
                      isUser: false,
                      child: _toolIndicator(item),
                    );
                  case ChatItemType.thinking:
                    return _chatBubble(
                      isUser: false,
                      child: Text(
                        '💭 ${item.text}',
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.blue,
                        ),
                      ),
                    );
                  case ChatItemType.error:
                    return _chatBubble(
                      isUser: false,
                      child: Text(
                        '⚠️ ${item.text}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                }
              },
            ),
          ),
        ),
        if (c.sending) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  minLines: 1,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Ask me anything...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _send(context),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: c.sending ? null : () => _send(context),
                child: const Text('Send'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chatBubble({required bool isUser, required Widget child}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isUser ? Colors.deepPurple : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: DefaultTextStyle(
          style: TextStyle(color: isUser ? Colors.white : Colors.black87),
          child: child,
        ),
      ),
    );
  }

  Widget _toolIndicator(ChatItem item) {
    Color color;
    IconData icon;
    switch (item.toolStatus) {
      case 'executing':
        color = Colors.blue.shade100;
        icon = Icons.play_arrow;
        break;
      case 'completed':
        color = Colors.green.shade100;
        icon = Icons.check;
        break;
      default:
        color = Colors.red.shade100;
        icon = Icons.close;
    }
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text('Tool ${item.toolStatus}: ${item.toolName}'),
        ],
      ),
    );
  }

  void _send(BuildContext context) {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    final controller = context.read<HomeController>();
    controller.sendMessage(text, 'flutter://home');
  }
}
