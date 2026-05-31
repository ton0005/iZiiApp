import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'module_interface.dart';
import 'module_registry.dart';

class ModuleDashboardScreen extends StatelessWidget {
  final String moduleId;

  const ModuleDashboardScreen({super.key, required this.moduleId});

  @override
  Widget build(BuildContext context) {
    final module = ModuleRegistry().getModule(moduleId);

    if (module == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Module')),
        body: const Center(
          child: Text(
            'Không thể tải module. Đã xảy ra lỗi khi cài đặt.',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final actions = _moduleActions(moduleId);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(module.manifest.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModuleHeader(context, module)
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.1, end: 0),
            const SizedBox(height: 32),
            if (module.dashboardWidget != null) ...[
              _buildSectionTitle(context, 'Tổng quan'),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.1),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: module.dashboardWidget!,
              )
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms)
                  .slideY(begin: 0.1, end: 0),
              const SizedBox(height: 32),
            ],
            _buildSectionTitle(context, 'Điều hướng nhanh'),
            const SizedBox(height: 16),
            _buildActionGrid(context, actions)
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms)
                .slideY(begin: 0.1, end: 0),
            const SizedBox(height: 48),
            Center(
              child: Text(
                module.manifest.description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleHeader(BuildContext context, IZiiModule module) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.extension_rounded, size: 40, color: Colors.white),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.manifest.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: theme.dividerColor.withOpacity(0.2)),
                      ),
                      child: Text(
                        'v${module.manifest.version}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 12, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Text(
                            'Active',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildActionGrid(BuildContext context, List<_ModuleAction> actions) {
    if (actions.isEmpty) {
      return Center(
        child: Text(
          'Không có hành động điều hướng nào được thiết lập.',
          style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withOpacity(0.5)),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1, // Slightly taller than wide
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        final theme = Theme.of(context);
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          child: InkWell(
            onTap: () => context.push(action.path),
            borderRadius: BorderRadius.circular(20),
            splashColor: Color(0xFF6366F1).withOpacity(0.1),
            highlightColor: Color(0xFF6366F1).withOpacity(0.05),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.dividerColor.withOpacity(0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFF6366F1).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(action.icon,
                        color: const Color(0xFF6366F1), size: 28),
                  ),
                  const Spacer(),
                  Text(
                    action.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<_ModuleAction> _moduleActions(String moduleId) {
    if (moduleId == 'izii.sales_crm') {
      return const [
        _ModuleAction(
          label: 'Quản lý Leads',
          subtitle: 'Khách hàng tiềm năng',
          path: '/crm/leads',
          icon: Icons.person_search_rounded,
        ),
        _ModuleAction(
          label: 'Deal Pipeline',
          subtitle: 'Theo dõi cơ hội',
          path: '/crm/deals',
          icon: Icons.bar_chart_rounded,
        ),
      ];
    }

    if (moduleId == 'izii.supply_chain') {
      return const [
        _ModuleAction(
          label: 'Products & Stock',
          subtitle: 'Inventory management',
          path: '/inventory/products',
          icon: Icons.inventory_2_rounded,
        ),
      ];
    }

    if (moduleId == 'izii.services') {
      return const [
        _ModuleAction(
          label: 'Danh sách Dịch vụ',
          subtitle: 'Sửa chữa, Lắp đặt, Điện nước',
          path: '/services/list',
          icon: Icons.home_repair_service_rounded,
        ),
        _ModuleAction(
          label: 'Đơn đặt Dịch vụ',
          subtitle: 'Theo dõi & quản lý đơn',
          path: '/services/bookings',
          icon: Icons.event_note_rounded,
        ),
      ];
    }

    return const [];
  }
}

class _ModuleAction {
  final String label;
  final String subtitle;
  final String path;
  final IconData icon;

  const _ModuleAction({
    required this.label,
    required this.subtitle,
    required this.path,
    required this.icon,
  });
}
