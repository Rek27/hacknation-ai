import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/service/agent_api.dart';
import 'package:frontend/service/api_client.dart';
import 'package:frontend/view/home/home_controller.dart';
import 'package:frontend/view/home/widgets/home_desktop_layout.dart';
import 'package:frontend/view/home/widgets/home_mobile_layout.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // NOTE:
    // - Default connects to hosted backend (ngrok).
    // - Override anytime with:
    //   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000   (Android emulator -> local PC)
    //   flutter run --dart-define=API_BASE_URL=http://localhost:8000  (desktop/web -> local)
    const envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const hostedBaseUrl =
        'https://b991-2001-4ca0-0-f237-1562-d89a-324c-8866.ngrok-free.app/';

    final baseUrl = envBaseUrl.isNotEmpty ? envBaseUrl : hostedBaseUrl;

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
  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool isMobile = width < AppConstants.kMobileBreakpoint;
    return Scaffold(
      appBar: null,
      drawer: null,
      body: isMobile
          ? const HomeMobileLayout()
          : HomeDesktopLayout(baseUrl: widget.baseUrl),
    );
  }
}
