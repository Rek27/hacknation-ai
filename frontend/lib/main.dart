import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rive/rive.dart';

import 'package:frontend/config/app_theme.dart';
import 'package:frontend/debug_log.dart';
import 'package:frontend/view/home/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RiveNative.init();
  // #region agent log
  final tempDir = await getTemporaryDirectory();
  final logPath = '${tempDir.path}/cursor_debug.log';
  setDebugLogPath(logPath);
  // #endregion
  runApp(const AgentApp());
}

class AgentApp extends StatelessWidget {
  const AgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Agent Chat',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}
