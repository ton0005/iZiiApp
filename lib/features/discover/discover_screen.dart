import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/izii_colors.dart';
import 'widgets/category_chip.dart';
import 'widgets/provider_card.dart';

/// The Discover screen — lets users search for and browse service providers.
/// Uses mock data and local state management (StatefulWidget).
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  // ── Demo data ────────────────────────────────────────────────────────

  final List<Map<String, Object>> _demoProviders = [
    {
      'name': 'Nguyễn Văn An',
      'service': 'Sửa chữa điện lạnh',
      'type': 'repair',
      'rating': 4.8,
      'distance': 2.3,
      'trustLevel': 'elite',
      'completedOrders': 156,
      'price': '200k–500k',
    },
    {
      'name': 'Hoàng Thanh Sơn',
      'service': 'Sửa máy giặt tại nhà',
      'type': 'repair',
      'rating': 4.7,
      'distance': 1.9,
      'trustLevel': 'verified',
      'completedOrders': 132,
      'price': '180k–450k',
    },
    {
      'name': 'Phạm Minh Tuấn',
      'service': 'Sửa ống nước và van',
      'type': 'repair',
      'rating': 4.3,
      'distance': 3.8,
      'trustLevel': 'trusted',
      'completedOrders': 45,
      'price': '150k–400k',
    },
    {
      'name': 'Trần Thị Bích',
      'service': 'Lắp đặt camera an ninh',
      'type': 'installation',
      'rating': 4.5,
      'distance': 5.1,
      'trustLevel': 'verified',
      'completedOrders': 89,
      'price': '500k–2M',
    },
    {
      'name': 'Bùi Thị Mai',
      'service': 'Lắp đặt đèn LED và quạt',
      'type': 'installation',
      'rating': 4.6,
      'distance': 4.6,
      'trustLevel': 'trusted',
      'completedOrders': 112,
      'price': '250k–900k',
    },
    {
      'name': 'Lê Ngọc Quý',
      'service': 'Chuyển nhà trọn gói',
      'type': 'delivery',
      'rating': 4.9,
      'distance': 1.2,
      'trustLevel': 'elite',
      'completedOrders': 312,
      'price': '800k–3M',
    },
    {
      'name': 'Lưu Thị Loan',
      'service': 'Giao hàng nhanh',
      'type': 'delivery',
      'rating': 4.4,
      'distance': 2.8,
      'trustLevel': 'verified',
      'completedOrders': 178,
      'price': '120k–650k',
    },
    {
      'name': 'Võ Thị Hương',
      'service': 'Dọn dẹp nhà cửa',
      'type': 'cleaning',
      'rating': 4.7,
      'distance': 0.8,
      'trustLevel': 'verified',
      'completedOrders': 203,
      'price': '300k–800k',
    },
    {
      'name': 'Trần Văn Khoa',
      'service': 'Vệ sinh văn phòng',
      'type': 'cleaning',
      'rating': 4.5,
      'distance': 2.0,
      'trustLevel': 'trusted',
      'completedOrders': 98,
      'price': '250k–700k',
    },
    {
      'name': 'Phạm Quỳnh Anh',
      'service': 'Điện nước gia đình',
      'type': 'electrical',
      'rating': 4.6,
      'distance': 1.5,
      'trustLevel': 'verified',
      'completedOrders': 167,
      'price': '200k–650k',
    },
    {
      'name': 'Đặng Minh Đức',
      'service': 'Sửa chữa điện, bảo trì',
      'type': 'electrical',
      'rating': 4.4,
      'distance': 3.2,
      'trustLevel': 'trusted',
      'completedOrders': 121,
      'price': '220k–700k',
    },
    {
      'name': 'Nguyễn Thùy Linh',
      'service': 'Lắp đặt mạng và wifi',
      'type': 'installation',
      'rating': 4.8,
      'distance': 3.4,
      'trustLevel': 'elite',
      'completedOrders': 204,
      'price': '350k–1.2M',
    },
    {
      'name': 'Hoàng Thanh Bình',
      'service': 'Tư vấn thiết kế nội thất',
      'type': 'other',
      'rating': 4.7,
      'distance': 5.9,
      'trustLevel': 'verified',
      'completedOrders': 72,
      'price': '400k–1.5M',
    },
  ];

  // ── Category definitions ─────────────────────────────────────────────

  static final _categories = <Map<String, dynamic>>[
    {
      'label': 'Tất cả',
      'icon': Icons.apps_rounded,
      'type': 'all',
      'tags': ['Sửa chữa', 'Lắp đặt', 'Vận chuyển', 'Dọn dẹp', 'Điện nước'],
    },
    {
      'label': 'Sửa chữa',
      'icon': Icons.build_rounded,
      'type': 'repair',
      'tags': ['Điện lạnh', 'Máy giặt', 'Ống nước'],
    },
    {
      'label': 'Lắp đặt',
      'icon': Icons.construction_rounded,
      'type': 'installation',
      'tags': ['Camera', 'Đèn', 'Wifi'],
    },
    {
      'label': 'Vận chuyển',
      'icon': Icons.local_shipping_rounded,
      'type': 'delivery',
      'tags': ['Chuyển nhà', 'Giao hàng'],
    },
    {
      'label': 'Dọn dẹp',
      'icon': Icons.cleaning_services_rounded,
      'type': 'cleaning',
      'tags': ['Nhà cửa', 'Văn phòng'],
    },
    {
      'label': 'Điện nước',
      'icon': Icons.electrical_services_rounded,
      'type': 'electrical',
      'tags': ['Sửa điện', 'Sửa nước'],
    },
    {
      'label': 'Khác',
      'icon': Icons.more_horiz_rounded,
      'type': 'other',
      'tags': ['Tư vấn', 'Tiện ích'],
    },
  ];

  // ── State ────────────────────────────────────────────────────────────

  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isLoading = false;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  // ── Computed filtered list ───────────────────────────────────────────

  List<Map<String, Object>> get _filteredProviders {
    var list = _demoProviders;

    // Filter by category
    if (_selectedCategory != 'all') {
      list = list.where((p) => p['type'] == _selectedCategory).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        final name = (p['name'] as String).toLowerCase();
        final svc = (p['service'] as String).toLowerCase();
        return name.contains(q) || svc.contains(q);
      }).toList();
    }

    return list;
  }

  // ── Pull-to-refresh simulation ───────────────────────────────────────

  Future<void> _onRefresh() async {
    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: IZiiColors.darkBackground,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: IZiiColors.primary,
        backgroundColor: IZiiColors.darkSurface,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── Header area ─────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: topPadding + 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Khám phá',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 500.ms, curve: Curves.easeOut)
                              .slideX(
                                  begin: -0.05,
                                  end: 0,
                                  duration: 500.ms,
                                  curve: Curves.easeOut),
                          const SizedBox(height: 4),
                          Text(
                            'Tìm dịch vụ phù hợp nhất cho bạn',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w400,
                            ),
                          ).animate().fadeIn(
                              duration: 500.ms,
                              delay: 100.ms,
                              curve: Curves.easeOut),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Search bar
                    _buildSearchBar(),

                    const SizedBox(height: 16),

                    // Category chips
                    _buildCategoryRow(),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── Results header ──────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Kết quả',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: IZiiColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_filteredProviders.length}',
                        style: const TextStyle(
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

            // ── Loading / Content / Empty ───────────────────
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: _LoadingIndicator(),
                ),
              )
            else if (_filteredProviders.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(query: _searchQuery),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final p = _filteredProviders[i];
                    return ProviderCard(
                      name: p['name'] as String,
                      service: p['service'] as String,
                      type: p['type'] as String,
                      rating: (p['rating'] as num).toDouble(),
                      distance: (p['distance'] as num).toDouble(),
                      trustLevel: p['trustLevel'] as String,
                      completedOrders: p['completedOrders'] as int,
                      price: p['price'] as String,
                      index: i,
                    );
                  },
                  childCount: _filteredProviders.length,
                ),
              ),

            // Bottom spacing
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ── Search bar ───────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: IZiiColors.darkSurface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: IZiiColors.darkSurfaceHighlight.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm dịch vụ, thợ...',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded,
                    color: IZiiColors.primary.withValues(alpha: 0.7), size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.4), size: 20),
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
    )
        .animate()
        .fadeIn(duration: 450.ms, delay: 150.ms, curve: Curves.easeOut)
        .slideY(
          begin: 0.06,
          end: 0,
          duration: 450.ms,
          delay: 150.ms,
          curve: Curves.easeOut,
        );
  }

  // ── Category row ─────────────────────────────────────────────────────

  Widget _buildCategoryRow() {
    return _ScrollableCategoryRow(
      selectedCategory: _selectedCategory,
      categories: _categories,
      onCategorySelected: (type) => setState(() => _selectedCategory = type),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Scrollable category row with fade edges + dots ─────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _ScrollableCategoryRow extends StatefulWidget {
  final String selectedCategory;
  final List<Map<String, dynamic>> categories;
  final ValueChanged<String> onCategorySelected;

  const _ScrollableCategoryRow({
    required this.selectedCategory,
    required this.categories,
    required this.onCategorySelected,
  });

  @override
  State<_ScrollableCategoryRow> createState() => _ScrollableCategoryRowState();
}

class _ScrollableCategoryRowState extends State<_ScrollableCategoryRow> {
  final ScrollController _controller = ScrollController();
  bool _showLeftFade = false;
  bool _showRightFade = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
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
    const fadeColor = IZiiColors.darkBackground;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 44,
          child: Stack(
            children: [
              ListView.separated(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                itemCount: widget.categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = widget.categories[i];
                  final type = cat['type'] as String;
                  return CategoryChip(
                    icon: cat['icon'] as IconData,
                    label: cat['label'] as String,
                    isSelected: widget.selectedCategory == type,
                    onTap: () => widget.onCategorySelected(type),
                  );
                },
              ),

              // Left fade
              if (_showLeftFade)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 24,
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
                  width: 24,
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
        const SizedBox(height: 6),
        _CategoryScrollDots(
          controller: _controller,
          itemCount: widget.categories.length,
          visibleCount: 4,
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 250.ms, curve: Curves.easeOut)
        .slideX(
          begin: 0.04,
          end: 0,
          duration: 400.ms,
          delay: 250.ms,
          curve: Curves.easeOut,
        );
  }
}

// ── Category scroll dots ───────────────────────────────────────────────

class _CategoryScrollDots extends StatefulWidget {
  final ScrollController controller;
  final int itemCount;
  final int visibleCount;

  const _CategoryScrollDots({
    required this.controller,
    required this.itemCount,
    required this.visibleCount,
  });

  @override
  State<_CategoryScrollDots> createState() => _CategoryScrollDotsState();
}

class _CategoryScrollDotsState extends State<_CategoryScrollDots> {
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
    final dotCount =
        (widget.itemCount - widget.visibleCount + 1).clamp(2, widget.itemCount);
    final activeIndex = (_scrollFraction * (dotCount - 1)).round();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(dotCount, (i) {
        final isActive = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          width: isActive ? 14 : 5,
          height: 5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2.5),
            color: isActive
                ? IZiiColors.primary
                : IZiiColors.primary.withValues(alpha: 0.2),
          ),
        );
      }),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Empty state ────────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final String query;
  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration circle
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    IZiiColors.primary.withValues(alpha: 0.15),
                    IZiiColors.secondary.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 44,
                color: IZiiColors.primary.withValues(alpha: 0.5),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
                begin: 1.0,
                end: 1.06,
                duration: 2000.ms,
                curve: Curves.easeInOut),

            const SizedBox(height: 24),

            Text(
              query.isNotEmpty
                  ? 'Không tìm thấy kết quả'
                  : 'Không có dịch vụ nào',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              query.isNotEmpty
                  ? 'Hãy thử tìm kiếm với từ khóa khác hoặc chọn danh mục khác.'
                  : 'Hãy chọn một danh mục để bắt đầu tìm kiếm dịch vụ.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.45),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, curve: Curves.easeOut)
        .scaleXY(begin: 0.95, end: 1, duration: 500.ms, curve: Curves.easeOut);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Loading indicator ──────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(IZiiColors.primary),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Đang tìm kiếm...',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
