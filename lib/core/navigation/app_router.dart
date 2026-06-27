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
import '../../modules/sales_crm/screens/deal_detail_screen.dart';
import '../../modules/sales_crm/bloc/crm_bloc.dart';
import '../../modules/supply_chain/supply_chain_module.dart';
import '../../modules/services/services_module.dart';
import '../../modules/project/project_module.dart';
import '../../modules/project/screens/project_list_screen.dart';
import '../../modules/project/screens/task_board_screen.dart';
import '../../modules/purchase/purchase_module.dart';
import '../../modules/purchase/screens/purchase_orders_list_screen.dart';
import '../../modules/purchase/screens/purchase_order_form_screen.dart';
import '../../modules/accountant/bloc/accountant_bloc.dart';
import '../../modules/accountant/screens/chart_of_accounts_screen.dart';
import '../../modules/accountant/screens/add_journal_entry_screen.dart';
import '../../modules/accountant/screens/financial_reports_screen.dart';
import '../../modules/accountant/screens/payroll_payrun_screen.dart';
import '../../modules/mushrooms/mushrooms_module.dart';
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
import '../../features/sharing/shared_with_me_screen.dart';
import '../../features/sharing/community_feed_screen.dart';
import '../../modules/communication/screens/chat_inbox_screen.dart';
import '../../modules/communication/screens/conversation_screen.dart';

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
  for (final t in ProjectModule().agentTools) {
    registry.registerTool(t);
  }
  for (final t in PurchaseModule().agentTools) {
    registry.registerTool(t);
  }
  for (final t in MushroomsModule().agentTools) {
    registry.registerTool(t);
  }
  return registry;
}

final _aiAgentService = AiAgentService(toolRegistry: _buildToolRegistry());

final _moduleRegistry = ModuleRegistry()..registerDefaultModuleFactories();

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
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
      path: '/crm/deals/detail',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.sales_crm'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final deal = state.extra as Map<String, dynamic>?;
          if (deal != null) {
            return DealDetailScreen(deal: deal);
          }

          final dealId = state.uri.queryParameters['dealId'] ?? '';
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: CrmRepository().getDeals(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              final deals = snapshot.data ?? [];
              final dealData = deals.firstWhere(
                (d) => d['id'] == dealId,
                orElse: () => <String, dynamic>{},
              );
              if (dealData.isEmpty) {
                return const Scaffold(
                  body: Center(child: Text('Deal not found')),
                );
              }
              return DealDetailScreen(deal: dealData);
            },
          );
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
    GoRoute(
      path: '/sharing/shared-with-me',
      builder: (context, state) => const SharedWithMeScreen(),
    ),
    GoRoute(
      path: '/sharing/community-feed',
      builder: (context, state) => const CommunityFeedScreen(),
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
    // Project module routes
    GoRoute(
      path: '/project',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.project_management'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return const ModuleDashboardScreen(
              moduleId: 'izii.project_management');
        },
      ),
    ),
    GoRoute(
      path: '/project/list',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.project_management'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return const ProjectListScreen();
        },
      ),
    ),
    GoRoute(
      path: '/project/tasks',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.project_management'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final projectId = state.uri.queryParameters['projectId'] ?? '';
          final projectName =
              state.uri.queryParameters['projectName'] ?? 'Tasks';
          return TaskBoardScreen(
              projectId: projectId, projectName: projectName);
        },
      ),
    ),
    // Purchase module routes
    GoRoute(
      path: '/purchase',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.purchase_management'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return const ModuleDashboardScreen(
              moduleId: 'izii.purchase_management');
        },
      ),
    ),
    GoRoute(
      path: '/purchase/list',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.purchase_management'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return const PurchaseOrdersListScreen();
        },
      ),
    ),
    GoRoute(
      path: '/purchase/create',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.purchase_management'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return const PurchaseOrderFormScreen();
        },
      ),
    ),
    // Accountant module routes
    GoRoute(
      path: '/accountant',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.accountant'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return const ModuleDashboardScreen(moduleId: 'izii.accountant');
        },
      ),
    ),
    GoRoute(
      path: '/accountant/coa',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.accountant'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return BlocProvider(
            create: (context) => AccountantBloc(),
            child: const ChartOfAccountsScreen(),
          );
        },
      ),
    ),
    GoRoute(
      path: '/accountant/journal',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.accountant'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return BlocProvider(
            create: (context) => AccountantBloc(),
            child: const AddJournalEntryScreen(),
          );
        },
      ),
    ),
    GoRoute(
      path: '/accountant/reports',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.accountant'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return BlocProvider(
            create: (context) => AccountantBloc(),
            child: const FinancialReportsScreen(),
          );
        },
      ),
    ),
    GoRoute(
      path: '/accountant/payroll',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.accountant'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return BlocProvider(
            create: (context) => AccountantBloc(),
            child: const PayrollPayrunScreen(),
          );
        },
      ),
    ),
    GoRoute(
      path: '/mushrooms',
      builder: (context, state) => FutureBuilder(
        future: _moduleRegistry.installModule('izii.mushrooms'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final module =
              _moduleRegistry.getModule('izii.mushrooms') as MushroomsModule;
          return module.routes['/mushrooms']!(context);
        },
      ),
    ),
    GoRoute(
      path: '/chat/inbox',
      builder: (context, state) => const ChatInboxScreen(),
    ),
    GoRoute(
      path: '/chat/conversation/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ConversationScreen(conversationId: id);
      },
    ),
  ],
);
