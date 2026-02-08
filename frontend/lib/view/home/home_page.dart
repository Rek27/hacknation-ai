import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/config/app_theme.dart';
import 'package:frontend/model/api_models.dart';
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
    const hostedBaseUrl = 'http://localhost:8000';

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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: isMobile
          ? null
          : AppBar(
              title: const Text('AI Agent Chat'),
              actions: [_AppBarActions(baseUrl: widget.baseUrl)],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: colorScheme.outlineVariant),
              ),
            ),
      drawer: null,
      body: isMobile ? const HomeMobileLayout() : const HomeDesktopLayout(),
    );
  }
}

class _AppBarActions extends StatelessWidget {
  const _AppBarActions({required this.baseUrl});

  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final HomeController controller = context.watch<HomeController>();
    final HealthStatus? health = controller.health;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isHealthy = health?.status == 'healthy';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'API: $baseUrl',
          child: Padding(
            padding: const EdgeInsets.only(right: AppConstants.spacingSm),
            child: Center(
              child: Text(
                'API',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        Icon(
          isHealthy ? Icons.check_circle : Icons.error,
          color: isHealthy ? AppTheme.success : colorScheme.error,
          size: AppConstants.iconSizeXs,
        ),
        const SizedBox(width: AppConstants.spacingSm),
        if (health != null)
          Padding(
            padding: const EdgeInsets.only(right: AppConstants.spacingMd),
            child: Center(
              child: Text(
                'Sessions: ${health.activeSessions}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
