import 'package:flutter/material.dart';
import 'package:frontend/config/app_theme.dart';
import 'package:frontend/view/home/home_page.dart';

void main() {
  runApp(const AgentApp());
}

class AgentApp extends StatelessWidget {
  const AgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Agent Chat',
      theme: AppTheme.theme,
      home: const HomePage(),
    );
  }
}
