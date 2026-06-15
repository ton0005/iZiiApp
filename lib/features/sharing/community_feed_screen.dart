import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/izii_colors.dart';
import '../../core/sync/sharing_repository.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/settings/settings_service.dart';

User _defaultUser(
    {required String id, required String name, required String type}) {
  return User(
    id: id,
    name: name,
    email: null,
    phone: null,
    type: type,
    kycStatus: 'none',
    createdAt: DateTime.now(),
  );
}

TrustScore _defaultTrustScore(String userId) {
  return TrustScore(
    userId: userId,
    overallScore: 5.0,
    referralCount: 0,
    referredBy: null,
    completedOrders: 0,
    avgRating: 5.0,
    memberSince: DateTime.now(),
    level: 'newcomer',
    kycVerified: false,
    tinScore: 5.0,
    tamScore: 5.0,
    nhanScore: 5.0,
    overallHti: 5.0,
    completedTransactions: 0,
    mutualAidCompleted: 0,
    amicableDisputesResolved: 0,
    updatedAt: DateTime.now(),
  );
}

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final AppDatabase _db = AppDatabase();
  final SharingRepository _sharingRepo = SharingRepository();

  bool _isLoading = true;
  List<Map<String, dynamic>> _communityServices = [];
  List<Map<String, dynamic>> _mutualAidTasks = [];

  @override
  void initState() {
    super.initState();
    _loadCommunityFeed();
  }

  Future<String> _getActiveUserId() async {
    try {
      return await SettingsService().getActiveUserId();
    } catch (_) {
      return 'default_user';
    }
  }

  Future<void> _loadCommunityFeed() async {
    setState(() => _isLoading = true);

    // Fetch public community service listings
    final serviceListings = await (_db.select(_db.serviceListings)
          ..where((tbl) =>
              tbl.visibility.equals('community') &
              tbl.isAvailable.equals(true)))
        .get();

    // Fetch public community tasks (volunteering opportunities)
    final communityTasks = await (_db.select(_db.tasks)
          ..where((tbl) =>
              tbl.visibility.equals('community') & tbl.status.equals('todo')))
        .get();

    final users = await _db.select(_db.users).get();
    final trustScores = await _db.select(_db.trustScores).get();

    final List<Map<String, dynamic>> servicesData = [];
    for (var s in serviceListings) {
      final provider = users.firstWhere((u) => u.id == s.providerId,
          orElse: () =>
              _defaultUser(id: '', name: 'Cộng tác viên', type: 'both'));
      final trust = trustScores.firstWhere((t) => t.userId == s.providerId,
          orElse: () => _defaultTrustScore(''));

      servicesData.add({
        'id': s.id,
        'title': s.title,
        'description': s.description,
        'price_min': s.priceMin,
        'price_max': s.priceMax,
        'location': s.location ?? 'Cộng đồng',
        'provider_name': provider.name,
        'provider_hti': trust.overallHti,
        'provider_level': trust.level,
      });
    }

    final List<Map<String, dynamic>> tasksData = [];
    for (var t in communityTasks) {
      // Find project description or creator
      final proj = await (_db.select(_db.projects)
            ..where((tbl) => tbl.id.equals(t.projectId)))
          .getSingleOrNull();
      final creatorName = proj != null ? 'Hàng xóm' : 'Ẩn danh';

      tasksData.add({
        'id': t.id,
        'title': t.title,
        'description': t.description ?? 'Cần hỗ trợ công việc này.',
        'priority': t.priority,
        'creator': creatorName,
        'created_at': t.createdAt,
      });
    }

    if (mounted) {
      setState(() {
        _communityServices = servicesData;
        _mutualAidTasks = tasksData;
        _isLoading = false;
      });
    }
  }

  Future<void> _claimMutualAidTask(String taskId, String taskTitle) async {
    final userId = await _getActiveUserId();

    // Update task status in database to done (simulating completed assistance)
    await (_db.update(_db.tasks)..where((tbl) => tbl.id.equals(taskId)))
        .write(const TasksCompanion(status: Value('done')));

    // Insert a mock completed service order on server database to reward Tâm (Compassion)
    // We insert a completed service order with price 0.0 to automatically trigger recalculated HTI
    await _db.into(_db.serviceOrders).insert(
          ServiceOrdersCompanion.insert(
            id: const Uuid().v4(),
            consumerId: 'neighbor-consumer-uuid',
            providerId: userId,
            serviceListingId: 'listing-mock-uuid',
            status: const Value('completed'),
            description: 'Hỗ trợ: $taskTitle',
            totalPrice: const Value(0.0), // price 0.0 = Mutual Aid
          ),
        );

    // Recalculate HTI to reflect completed volunteer work
    await _sharingRepo.recalculateUserHti(userId);

    _showCompletionDialog(taskTitle);
    _loadCommunityFeed();
  }

  void _showCompletionDialog(String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.favorite_rounded, color: Colors.pink, size: 28),
            const SizedBox(width: 8),
            Text(context.tr('sharing_thank_you'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(context.tr('sharing_volunteer_reward').replaceAll('{title}', title)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1)),
            onPressed: () => Navigator.pop(context),
            child:
                Text(context.tr('sharing_confirm'), style: const TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor:
            isDark ? IZiiColors.darkBackground : IZiiColors.lightBackground,
        appBar: AppBar(
          title: Text(context.tr('sharing_community_feed_title'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
              ),
            ),
          ),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.cleaning_services_rounded), text: context.tr('sharing_tab_services')),
              Tab(
                  icon: const Icon(Icons.volunteer_activism_rounded),
                  text: context.tr('sharing_tab_neighbor_aid')),
            ],
            indicatorColor: Colors.white,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildServicesFeed(cardColor),
                  _buildTasksFeed(cardColor),
                ],
              ),
      ),
    );
  }

  Widget _buildServicesFeed(Color cardColor) {
    if (_communityServices.isEmpty) {
      return _buildEmptyState(context.tr('sharing_no_services'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _communityServices.length,
      itemBuilder: (context, index) {
        final s = _communityServices[index];
        final priceText = (s['price_min'] == null)
            ? 'Liên hệ báo giá'
            : '${s['price_min']}k - ${s['price_max']}k AUD';

        return Card(
          color: cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(s['title'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(priceText,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(s['description'] as String,
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const Divider(height: 20),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          const Color(0xFF10B981).withValues(alpha: 0.12),
                      child: const Icon(Icons.person,
                          size: 14, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 8),
                    Text(s['provider_name'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.favorite_rounded,
                              color: Colors.amber, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            'HTI: ${s['provider_hti'].toStringAsFixed(1)}',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTasksFeed(Color cardColor) {
    if (_mutualAidTasks.isEmpty) {
      return _buildEmptyState(
          'Hiện tại không có việc hỗ trợ hàng xóm nào cần giúp đỡ.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _mutualAidTasks.length,
      itemBuilder: (context, index) {
        final t = _mutualAidTasks[index];
        Color priorityColor = Colors.green;
        if (t['priority'] == 'high') priorityColor = Colors.red;
        if (t['priority'] == 'medium') priorityColor = Colors.orange;

        return Card(
          color: cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        t['priority'].toString().toUpperCase(),
                        style: TextStyle(
                            color: priorityColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t['title'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(t['description'] as String,
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Yêu cầu bởi: ${t['creator']}',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.volunteer_activism_rounded,
                          size: 14),
                      label: const Text('Hỗ trợ ngay',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _claimMutualAidTask(
                          t['id'] as String, t['title'] as String),
                    )
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.feed_outlined,
                color: Colors.grey.withValues(alpha: 0.4), size: 48),
            const SizedBox(height: 12),
            Text(
              msg,
              style: const TextStyle(
                  color: Colors.grey, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
