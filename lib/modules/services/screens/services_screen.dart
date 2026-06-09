import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:izii_app/core/theme/izii_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../bloc/services_bloc.dart';
import 'add_service_screen.dart';
import 'edit_service_screen.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  static const _categories = {
    'all': 'Tất cả',
    'repair': 'Sửa chữa',
    'installation': 'Lắp đặt',
    'delivery': 'Vận chuyển',
    'cleaning': 'Dọn dẹp',
    'electrical': 'Điện',
    'plumbing': 'Nước',
    'other': 'Khác',
  };

  static const _categoryIcons = {
    'repair': Icons.build_rounded,
    'installation': Icons.construction_rounded,
    'delivery': Icons.local_shipping_rounded,
    'cleaning': Icons.cleaning_services_rounded,
    'electrical': Icons.electrical_services_rounded,
    'plumbing': Icons.plumbing_rounded,
    'other': Icons.miscellaneous_services_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ServicesBloc()..add(LoadServicesEvent()),
      child: const _ServicesBody(),
    );
  }
}

class _ServicesBody extends StatefulWidget {
  const _ServicesBody();

  @override
  State<_ServicesBody> createState() => _ServicesBodyState();
}

class _ServicesBodyState extends State<_ServicesBody> {
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterServices(
      List<Map<String, dynamic>> services) {
    final query = _searchQuery.toLowerCase();
    return services.where((service) {
      final name = (service['name'] as String? ?? '').toLowerCase();
      final desc = (service['description'] as String? ?? '').toLowerCase();
      final category = (service['category'] as String? ?? '').toLowerCase();
      final baseMatch = name.contains(query) ||
          desc.contains(query) ||
          category.contains(query);
      final categoryMatch = _selectedCategory == 'all' ||
          service['category'] == _selectedCategory;
      return baseMatch && categoryMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IZiiColors.darkBackground,
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: Text(context.tr('ser_services_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            tooltip: 'Home',
            onPressed: () => context.go('/'),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
            ),
          ),
        ),
      ),
      body: BlocBuilder<ServicesBloc, ServicesState>(
        builder: (context, state) {
          final services = _filterServices(state.services);

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('module_izii.services_name'),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr('ser_intro_subtitle'),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.65),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSearchBar(),
                      const SizedBox(height: 16),
                      _buildCategoryRow(),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Row(
                    children: [
                      Text(
                        context.tr('ser_results_label'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: IZiiColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${services.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: IZiiColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (state.isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (services.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home_repair_service_outlined,
                            size: 96, color: Colors.white24),
                        const SizedBox(height: 20),
                        Text(
                          _searchQuery.isEmpty
                              ? context.tr('ser_no_services_found')
                              : context.tr('ser_no_matching_services'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.75),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? context.tr('ser_fab_add_prompt')
                              : context.tr('ser_search_different_prompt'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final service = services[index];
                      return _ServiceCard(
                        service: service,
                        onTap: () async {
                          final result = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditServiceScreen(service: service),
                            ),
                          );
                          if (result == true && context.mounted) {
                            context
                                .read<ServicesBloc>()
                                .add(LoadServicesEvent());
                          }
                        },
                      )
                          .animate()
                          .fadeIn(delay: (index * 50).ms, duration: 300.ms)
                          .slideX(begin: 0.05, end: 0);
                    },
                    childCount: services.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_service',
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddServiceScreen()),
          );
          if (result == true && context.mounted) {
            context.read<ServicesBloc>().add(LoadServicesEvent());
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('ser_add_service_button'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: IZiiColors.darkSurface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: IZiiColors.darkSurfaceHighlight.withOpacity(0.45),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: context.tr('ser_search_hint'),
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.35), fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded,
                    color: IZiiColors.primary.withOpacity(0.7), size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: Colors.white.withOpacity(0.5), size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRow() {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: ServicesScreen._categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = ServicesScreen._categories.entries.elementAt(index);
          final isSelected = _selectedCategory == entry.key;
          final icon = ServicesScreen._categoryIcons[entry.key] ??
              Icons.miscellaneous_services_rounded;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? IZiiColors.primary.withOpacity(0.18)
                    : IZiiColors.darkSurface.withOpacity(0.65),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? IZiiColors.primary
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon,
                      size: 18,
                      color: isSelected ? IZiiColors.primary : Colors.white70),
                  const SizedBox(width: 10),
                  Text(
                    context.tr('ser_cat_${entry.key}'),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final VoidCallback onTap;

  const _ServiceCard({required this.service, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = service['category'] as String? ?? 'other';
    final icon = ServicesScreen._categoryIcons[category] ??
        Icons.miscellaneous_services_rounded;
    final isActive = service['is_active'] as bool? ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF8B5CF6), size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            service['name'] ?? '',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(context.tr('ser_inactive_badge'),
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('ser_cat_$category'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatPrice(service['hourly_rate']),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  Text(
                    context.tr('ser_price_unit'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price is num) {
      if (price >= 1000000) return '${(price / 1000000).toStringAsFixed(1)}M';
      if (price >= 1000) return '${(price / 1000).toStringAsFixed(0)}K';
      return price.toStringAsFixed(0);
    }
    return '0';
  }
}
