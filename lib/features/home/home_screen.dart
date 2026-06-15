import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/bloc/app_bloc.dart';
import '../../core/modules/module_registry.dart';
import '../../core/theme/izii_colors.dart';
import '../../modules/sales_crm/bloc/crm_bloc.dart';
import '../../modules/services/repository.dart';
import '../../modules/supply_chain/repository.dart';
import '../../core/localization/app_localizations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final availableModules = ModuleRegistry().availableModuleManifests;
    final moduleCount = availableModules.length;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- App Bar ---
          SliverAppBar(
            leading: Navigator.of(context).canPop()
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                : null,
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: isDark ? IZiiColors.darkBackground : Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: IZiiColors.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('home_app_name'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: isDark ? Colors.white : IZiiColors.darkBackground,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      IZiiColors.primary.withValues(alpha: 0.15),
                      IZiiColors.secondary.withValues(alpha: 0.08),
                      isDark ? IZiiColors.darkBackground : Colors.white,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.brightness_6_rounded, size: 22),
                onPressed: () {
                  context.read<AppBloc>().add(ToggleThemeEvent());
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded, size: 22),
                onPressed: () => context.push('/settings'),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // --- Search Bar ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: GestureDetector(
                onTap: () => context.go('/services/list'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? IZiiColors.darkSurface
                        : IZiiColors.lightSurfaceHighlight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded,
                          color: IZiiColors.primary.withValues(alpha: 0.7),
                          size: 22),
                      const SizedBox(width: 12),
                      Text(
                        context.tr('home_search_hint'),
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.4)
                              : Colors.black.withValues(alpha: 0.4),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- Quick Actions ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                context.tr('home_quick_actions_title'),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : IZiiColors.darkBackground,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _ScrollableRow(
              height: 110,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _QuickAction(
                  icon: Icons.smart_toy_rounded,
                  label: context.tr('home_action_chat_ai'),
                  gradient: const LinearGradient(
                    colors: [IZiiColors.primary, Color(0xFF818CF8)],
                  ),
                  onTap: () => context.go('/chat'),
                ),
                _QuickAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: context.tr('home_action_direct_chat'),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFC084FC)],
                  ),
                  onTap: () => context.push('/chat/inbox'),
                ),
                _QuickAction(
                  icon: Icons.handyman_rounded,
                  label: context.tr('home_action_services'),
                  gradient: const LinearGradient(
                    colors: [IZiiColors.secondary, Color(0xFF22D3EE)],
                  ),
                  onTap: () => context.go('/services/list'),
                ),
                _QuickAction(
                  icon: Icons.people_rounded,
                  label: context.tr('home_action_opportunities'),
                  gradient: const LinearGradient(
                    colors: [IZiiColors.success, Color(0xFF34D399)],
                  ),
                  onTap: () => context.push('/sales'),
                ),
                _QuickAction(
                  icon: Icons.inventory_2_rounded,
                  label: context.tr('home_action_inventory'),
                  gradient: const LinearGradient(
                    colors: [IZiiColors.accent, Color(0xFFFBBF24)],
                  ),
                  onTap: () => context.push('/inventory'),
                ),
                _QuickAction(
                  icon: Icons.apps_rounded,
                  label: context.tr('home_action_izii_store'),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF8B5CF6)],
                  ),
                  onTap: () => context.push('/modules'),
                ),
                _QuickAction(
                  icon: Icons.person_add_rounded,
                  label: context.tr('home_action_invite_friends'),
                  gradient: const LinearGradient(
                    colors: [IZiiColors.error, Color(0xFFFB7185)],
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              context.tr('home_action_invite_coming_soon'))),
                    );
                  },
                ),
                _QuickAction(
                  icon: Icons.receipt_long_rounded,
                  label: context.tr('home_action_orders'),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr('home_action_orders'))),
                    );
                  },
                ),
                _QuickAction(
                  icon: Icons.bar_chart_rounded,
                  label: context.tr('home_action_reports'),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr('home_action_reports'))),
                    );
                  },
                ),
              ],
            ),
          ),

          // --- Business Modules Section ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  Text(
                    context.tr('home_module_business_title'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : IZiiColors.darkBackground,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: IZiiColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      context.tr('home_module_installed_count').replaceAll('{count}', '$moduleCount'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: IZiiColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              delegate: SliverChildListDelegate(availableModules.map((module) {
                return _ModuleCard(
                  icon: _iconForModule(module.id),
                  title: module.name,
                  subtitle: module.category,
                  color: _colorForModule(module.id),
                  onTap: () => context.push(_routeForModule(module.id)),
                );
              }).toList()),
            ),
          ),

          // --- Recent Activity ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Text(
                context.tr('home_action_feed_title'),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : IZiiColors.darkBackground,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FutureBuilder<List<_HomeActionFeedEntry>>(
                future: _loadRecentActions(context.tr),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                            const SizedBox(width: 12),
                            Text(context.tr('home_feed_loading')),
                          ],
                        ),
                      ),
                    );
                  }

                  final feedItems = snapshot.data ?? [];
                  if (feedItems.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          context.tr('home_feed_empty'),
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: feedItems
                        .map((item) => _ActivityTile(
                              icon: item.icon,
                              iconColor: item.iconColor,
                              title: item.title,
                              subtitle: item.subtitle,
                            ))
                        .toList(),
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

Future<List<_HomeActionFeedEntry>> _loadRecentActions(String Function(String) tr) async {
  final leads = await CrmRepository().getLeads();
  final products = await SupplyChainRepository().getProductsWithStock();
  final serviceItems = await ServicesRepository().getServiceItems();
  final bookings = await ServicesRepository().getBookings();

  final entries = <_HomeActionFeedEntry>[];

  for (final lead in leads) {
    final createdAt = _parseCreatedAt(lead['created_at']);
    entries.add(_HomeActionFeedEntry(
      icon: Icons.person_add_rounded,
      iconColor: IZiiColors.success,
      title: tr('home_feed_new_lead').replaceAll('{name}', '${lead['title']}'),
      subtitle: '${lead['name']} • ${_formatRelativeTime(createdAt, tr)}',
      createdAt: createdAt,
    ));
  }

  for (final product in products) {
    final createdAt = _parseCreatedAt(product['created_at']);
    entries.add(_HomeActionFeedEntry(
      icon: Icons.inventory_rounded,
      iconColor: IZiiColors.accent,
      title: tr('home_feed_new_product').replaceAll('{name}', '${product['name']}'),
      subtitle: '${tr('home_feed_stock_label').replaceAll('{count}', '${product['stock']}')} • ${_formatRelativeTime(createdAt, tr)}',
      createdAt: createdAt,
    ));
  }

  for (final service in serviceItems) {
    final createdAt = _parseCreatedAt(service['created_at']);
    entries.add(_HomeActionFeedEntry(
      icon: Icons.handyman_rounded,
      iconColor: const Color(0xFF22D3EE),
      title: tr('home_feed_new_service').replaceAll('{name}', '${service['name']}'),
      subtitle: '${service['category']} • ${_formatRelativeTime(createdAt, tr)}',
      createdAt: createdAt,
    ));
  }

  for (final booking in bookings) {
    final createdAt = _parseCreatedAt(booking['created_at']);
    entries.add(_HomeActionFeedEntry(
      icon: Icons.home_repair_service_rounded,
      iconColor: IZiiColors.primary,
      title: tr('home_feed_new_booking').replaceAll('{name}', '${booking['service_name']}'),
      subtitle:
          '${booking['customer_name']} • ${_formatRelativeTime(createdAt, tr)}',
      createdAt: createdAt,
    ));
  }

  entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return entries.take(4).toList();
}

DateTime _parseCreatedAt(dynamic value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.now();
}

String _formatRelativeTime(DateTime dateTime, String Function(String) tr) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);
  final time = _formatTime(dateTime);

  if (diff.inMinutes < 60) {
    return tr('home_time_today').replaceAll('{time}', time);
  }
  if (diff.inHours < 24) {
    return tr('home_time_today').replaceAll('{time}', time);
  }
  if (diff.inHours < 48) {
    return tr('home_time_yesterday').replaceAll('{time}', time);
  }
  if (diff.inDays < 7) {
    return tr('home_time_days_ago').replaceAll('{days}', '${diff.inDays}').replaceAll('{time}', time);
  }
  return '${dateTime.day}/${dateTime.month} $time';
}

String _formatTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _HomeActionFeedEntry {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final DateTime createdAt;

  _HomeActionFeedEntry({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.createdAt,
  });
}

// --- Quick Action Card ---
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 88,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.colors.first.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Module Card ---
class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? IZiiColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : IZiiColors.darkBackground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconForModule(String moduleId) {
  switch (moduleId) {
    case 'izii.sales_crm':
      return Icons.people_alt_rounded;
    case 'izii.supply_chain':
      return Icons.inventory_2_rounded;
    case 'izii.services':
      return Icons.handyman_rounded;
    case 'izii.project_management':
      return Icons.assignment_rounded;
    case 'izii.purchase_management':
      return Icons.shopping_cart_rounded;
    case 'izii.accountant':
      return Icons.account_balance_rounded;
    case 'izii.mushrooms':
      return Icons.agriculture_rounded;
    default:
      return Icons.extension_rounded;
  }
}

Color _colorForModule(String moduleId) {
  switch (moduleId) {
    case 'izii.sales_crm':
      return IZiiColors.primary;
    case 'izii.supply_chain':
      return IZiiColors.accent;
    case 'izii.services':
      return const Color(0xFF22D3EE);
    case 'izii.project_management':
      return const Color(0xFF8B5CF6);
    case 'izii.purchase_management':
      return IZiiColors.success;
    case 'izii.accountant':
      return const Color(0xFF06B6D4);
    case 'izii.mushrooms':
      return const Color(0xFF10B981);
    default:
      return IZiiColors.primary;
  }
}

String _routeForModule(String moduleId) {
  switch (moduleId) {
    case 'izii.sales_crm':
      return '/sales';
    case 'izii.supply_chain':
      return '/inventory';
    case 'izii.services':
      return '/services/list';
    case 'izii.project_management':
      return '/project';
    case 'izii.purchase_management':
      return '/purchase';
    case 'izii.accountant':
      return '/accountant';
    case 'izii.mushrooms':
      return '/mushrooms';
    default:
      return '/';
  }
}

// --- Activity Tile ---
class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _ActivityTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? IZiiColors.darkSurface.withValues(alpha: 0.6)
              : IZiiColors.lightSurfaceHighlight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : IZiiColors.darkBackground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : Colors.black26,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Scrollable Row with fade edges + indicator dots ---
class _ScrollableRow extends StatefulWidget {
  final double height;
  final EdgeInsetsGeometry padding;
  final List<Widget> children;

  const _ScrollableRow({
    required this.height,
    required this.padding,
    required this.children,
  });

  @override
  State<_ScrollableRow> createState() => _ScrollableRowState();
}

class _ScrollableRowState extends State<_ScrollableRow> {
  final ScrollController _controller = ScrollController();
  bool _showLeftFade = false;
  bool _showRightFade = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    // Check initial state after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    setState(() {
      _showLeftFade = pos.pixels > 8;
      _showRightFade = pos.pixels < pos.maxScrollExtent - 8;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fadeColor = isDark ? IZiiColors.darkBackground : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: Stack(
            children: [
              // Scrollable content
              ListView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                padding: widget.padding,
                physics: const BouncingScrollPhysics(),
                children: widget.children,
              ),

              // Left fade
              if (_showLeftFade)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 28,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            fadeColor,
                            fadeColor.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Right fade
              if (_showRightFade)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 28,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            fadeColor,
                            fadeColor.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Scroll indicator dots
        const SizedBox(height: 8),
        _ScrollDots(
          controller: _controller,
          itemCount: widget.children.length,
          visibleCount: 4,
        ),
      ],
    );
  }
}

// --- Scroll position dots ---
class _ScrollDots extends StatefulWidget {
  final ScrollController controller;
  final int itemCount;
  final int visibleCount;

  const _ScrollDots({
    required this.controller,
    required this.itemCount,
    required this.visibleCount,
  });

  @override
  State<_ScrollDots> createState() => _ScrollDotsState();
}

class _ScrollDotsState extends State<_ScrollDots> {
  double _scrollFraction = 0.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final pos = widget.controller.position;
    if (pos.maxScrollExtent <= 0) return;
    setState(() {
      _scrollFraction = (pos.pixels / pos.maxScrollExtent).clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Number of dot positions = total pages (segments)
    final dotCount =
        (widget.itemCount - widget.visibleCount + 1).clamp(2, widget.itemCount);
    final activeIndex = (_scrollFraction * (dotCount - 1)).round();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(dotCount, (i) {
        final isActive = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: isActive
                ? IZiiColors.primary
                : IZiiColors.primary.withValues(alpha: 0.2),
          ),
        );
      }),
    );
  }
}
