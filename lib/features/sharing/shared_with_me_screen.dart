import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../../core/database/app_database.dart';
import '../../core/theme/izii_colors.dart';
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

class SharedWithMeScreen extends StatefulWidget {
  const SharedWithMeScreen({super.key});

  @override
  State<SharedWithMeScreen> createState() => _SharedWithMeScreenState();
}

class _SharedWithMeScreenState extends State<SharedWithMeScreen> {
  final AppDatabase _db = AppDatabase();

  bool _isLoading = true;
  List<Map<String, dynamic>> _sharedLeads = [];
  List<Map<String, dynamic>> _sharedDeals = [];
  List<Map<String, dynamic>> _sharedServices = [];
  List<Map<String, dynamic>> _sharedTasks = [];

  @override
  void initState() {
    super.initState();
    _loadSharedRecords();
  }

  Future<String> _getActiveUserId() async {
    try {
      return await SettingsService().getActiveUserId();
    } catch (_) {
      return 'default_user';
    }
  }

  Future<void> _loadSharedRecords() async {
    setState(() => _isLoading = true);
    final userId = await _getActiveUserId();

    // Query record sharing permissions matching current user
    final permissions = await (_db.select(_db.recordSharingPermissions)
          ..where(
              (tbl) => tbl.sharedWith.equals(userId) & tbl.revokedAt.isNull()))
        .get();

    final List<Map<String, dynamic>> tempLeads = [];
    final List<Map<String, dynamic>> tempDeals = [];
    final List<Map<String, dynamic>> tempServices = [];
    final List<Map<String, dynamic>> tempTasks = [];

    final users = await _db.select(_db.users).get();

    for (var perm in permissions) {
      if (perm.expiresAt != null && perm.expiresAt!.isBefore(DateTime.now())) {
        continue; // expired
      }

      final sharerName = users
          .firstWhere((u) => u.id == perm.sharedBy,
              orElse: () =>
                  _defaultUser(id: '', name: 'Cộng tác viên', type: 'both'))
          .name;

      switch (perm.recordType) {
        case 'leads':
          final rec = await (_db.select(_db.leads)
                ..where((tbl) => tbl.id.equals(perm.recordId)))
              .getSingleOrNull();
          if (rec != null) {
            tempLeads.add({
              'id': rec.id,
              'title': rec.title,
              'shared_by': sharerName,
              'permission': perm.permissionLevel,
              'expires_at': perm.expiresAt,
              'status': rec.status,
            });
          }
          break;
        case 'deals':
          final rec = await (_db.select(_db.deals)
                ..where((tbl) => tbl.id.equals(perm.recordId)))
              .getSingleOrNull();
          if (rec != null) {
            tempDeals.add({
              'id': rec.id,
              'title': rec.title,
              'shared_by': sharerName,
              'permission': perm.permissionLevel,
              'expires_at': perm.expiresAt,
              'amount': rec.amount,
            });
          }
          break;
        case 'services':
          final rec = await (_db.select(_db.serviceListings)
                ..where((tbl) => tbl.id.equals(perm.recordId)))
              .getSingleOrNull();
          if (rec != null) {
            tempServices.add({
              'id': rec.id,
              'title': rec.title,
              'shared_by': sharerName,
              'permission': perm.permissionLevel,
              'expires_at': perm.expiresAt,
              'rating': rec.rating,
            });
          }
          break;
        case 'service_items':
          final rec = await (_db.select(_db.serviceItems)
                ..where((tbl) => tbl.id.equals(perm.recordId)))
              .getSingleOrNull();
          if (rec != null) {
            tempServices.add({
              'id': rec.id,
              'title': rec.name,
              'shared_by': sharerName,
              'permission': perm.permissionLevel,
              'expires_at': perm.expiresAt,
              'rating': 0.0,
            });
          }
          break;
        case 'tasks':
          final rec = await (_db.select(_db.tasks)
                ..where((tbl) => tbl.id.equals(perm.recordId)))
              .getSingleOrNull();
          if (rec != null) {
            tempTasks.add({
              'id': rec.id,
              'title': rec.title,
              'shared_by': sharerName,
              'permission': perm.permissionLevel,
              'expires_at': perm.expiresAt,
              'status': rec.status,
            });
          }
          break;
      }
    }

    if (mounted) {
      setState(() {
        _sharedLeads = tempLeads;
        _sharedDeals = tempDeals;
        _sharedServices = tempServices;
        _sharedTasks = tempTasks;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor:
            isDark ? IZiiColors.darkBackground : IZiiColors.lightBackground,
        appBar: AppBar(
          title: Text(context.tr('sharing_shared_with_me_title'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
              ),
            ),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: context.tr('sharing_tab_leads')),
              Tab(text: context.tr('sharing_tab_deals')),
              Tab(text: context.tr('sharing_tab_services')),
              Tab(text: context.tr('sharing_tab_tasks')),
            ],
            indicatorColor: Colors.white,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildRecordList(_sharedLeads, Icons.people_alt_rounded,
                      'leads', cardColor),
                  _buildRecordList(_sharedDeals, Icons.monetization_on_rounded,
                      'deals', cardColor),
                  _buildRecordList(_sharedServices,
                      Icons.cleaning_services_rounded, 'services', cardColor),
                  _buildRecordList(_sharedTasks,
                      Icons.assignment_turned_in_rounded, 'tasks', cardColor),
                ],
              ),
      ),
    );
  }

  Widget _buildRecordList(
    List<Map<String, dynamic>> records,
    IconData icon,
    String type,
    Color cardColor,
  ) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.share_outlined,
                color: Colors.grey.withValues(alpha: 0.5), size: 48),
            const SizedBox(height: 12),
            Text(
              context.tr('sharing_no_shared_records'),
              style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final rec = records[index];
        final expiresText = rec['expires_at'] == null
            ? context.tr('sharing_forever')
            : '${rec['expires_at'].day}/${rec['expires_at'].month}/${rec['expires_at'].year}';

        return Card(
          color: cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.12),
              child: Icon(icon, color: const Color(0xFF6366F1)),
            ),
            title: Text(rec['title'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('${context.tr('sharing_shared_by')}: ${rec['shared_by']}',
                    style: const TextStyle(fontSize: 12)),
                Text('${context.tr('sharing_expiration_label')}: $expiresText',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: rec['permission'] == 'edit'
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                rec['permission'] == 'edit'
                    ? context.tr('sharing_permission_edit')
                    : context.tr('sharing_permission_view'),
                style: TextStyle(
                  color: rec['permission'] == 'edit'
                      ? const Color(0xFF10B981)
                      : Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            onTap: () {
              // Open detail logic per module (read-only or edit based on permission)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Đang mở bản ghi ${rec['title']} với quyền ${rec['permission']}'),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
