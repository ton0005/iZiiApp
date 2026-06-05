import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/home/home_screen.dart';
import '../ai_agent/ui/ai_chat_screen.dart';
import '../ai_agent/bloc/chat_bloc.dart';
import '../ai_agent/ai_agent_service.dart';
import '../ai_agent/tools/agent_tool_registry.dart';
import '../../modules/sales_crm/agent_tools/crm_tools.dart';
import '../../modules/sales_crm/ui/deal_pipeline.dart';
import '../../modules/sales_crm/screens/leads_screen.dart';
import '../../modules/supply_chain/supply_chain_module.dart';
import '../../modules/services/services_module.dart';
import '../modules/module_dashboard_screen.dart';
import '../modules/module_directory_screen.dart';
import '../modules/module_registry.dart';
import '../../modules/supply_chain/screens/products_screen.dart';
import '../../modules/services/screens/services_screen.dart';
import '../../modules/services/screens/bookings_screen.dart';
import '../settings/settings_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/discover/discover_screen.dart';
import 'scaffold_with_nav.dart';
import '../sync/screens/sync_screen.dart';

AgentToolRegistry _buildToolRegistry() {
  final registry = AgentToolRegistry();
  for (final tool in getCrmAgentTools()) {
    registry.registerTool(tool);
  }
  for (final t in SupplyChainModule().agentTools) {
    registry.registerTool(t);
  }
  for (final t in ServicesModule().agentTools) {
    registry.registerTool(t);
  }
  return registry;
}

final _aiAgentService = AiAgentService(toolRegistry: _buildToolRegistry());

final _moduleRegistry = ModuleRegistry()..registerDefaultModuleFactories();

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // Shell route with bottom navigation
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => ScaffoldWithNav(child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/chat',
          pageBuilder: (context, state) => NoTransitionPage(
            child: BlocProvider(
              create: (context) => ChatBloc(_aiAgentService),
              child: const AiChatScreen(),
            ),
          ),
        ),
        GoRoute(
          path: '/discover',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DiscoverScreen(),
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProfileScreen(),
          ),
        ),
      ],
    ),
    // Routes outside of shell (no bottom nav)
    GoRoute(
      path: '/sales',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.sales_crm'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return const ModuleDashboardScreen(moduleId: 'izii.sales_crm');
        },
      ),
    ),
    GoRoute(
      path: '/inventory',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.supply_chain'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return const ModuleDashboardScreen(moduleId: 'izii.supply_chain');
        },
      ),
    ),
    GoRoute(
      path: '/modules',
      builder: (context, state) => const ModuleDirectoryScreen(),
    ),
    GoRoute(
      path: '/crm/leads',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.sales_crm'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return const LeadsScreen();
        },
      ),
    ),
    GoRoute(
      path: '/crm/deals',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.sales_crm'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return const DealPipelineScreen();
        },
      ),
    ),
    GoRoute(
      path: '/inventory/products',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.supply_chain'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return const ProductsScreen();
        },
      ),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/settings/sync',
      builder: (context, state) => const SyncScreen(),
    ),
    // Services module routes
    GoRoute(
      path: '/services',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.services'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return const ModuleDashboardScreen(moduleId: 'izii.services');
        },
      ),
    ),
    GoRoute(
      path: '/services/list',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.services'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return const ServicesScreen();
        },
      ),
    ),
    GoRoute(
      path: '/services/bookings',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.services'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return const BookingsScreen();
        },
      ),
    ),
  ],
);
