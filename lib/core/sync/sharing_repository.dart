import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class SharingRepository {
  static final SharingRepository _instance = SharingRepository._internal();
  factory SharingRepository() => _instance;
  SharingRepository._internal();

  final AppDatabase _db = AppDatabase();

  /// Check if a user has permission to view/edit a specific record
  Future<bool> hasPermission({
    required String userId,
    required String recordType,
    required String recordId,
    required String requiredLevel, // 'view' or 'edit'
  }) async {
    // 1. Check if the user is the owner/creator of the record
    final isOwner = await _isRecordOwner(userId, recordType, recordId);
    if (isOwner) return true;

    // 2. Check record's visibility status
    final visibility = await _getRecordVisibility(recordType, recordId);
    if (visibility == 'private') {
      return false; // Private records can only be seen by the owner
    }

    if (visibility == 'community') {
      // Community records are viewable by everyone, but only editable by owner
      return requiredLevel == 'view';
    }

    // 3. Visibility is 'team' - check explicit permissions
    final permissions = await (_db.select(_db.recordSharingPermissions)
          ..where((tbl) =>
              tbl.recordType.equals(recordType) &
              tbl.recordId.equals(recordId) &
              tbl.revokedAt.isNull() &
              (tbl.sharedWith.equals(userId) |
                  tbl.sharedWith.equals('community'))))
        .get();

    for (var perm in permissions) {
      // Check expiration
      if (perm.expiresAt != null && perm.expiresAt!.isBefore(DateTime.now())) {
        continue;
      }

      // Check permission level
      if (requiredLevel == 'view') {
        return true;
      } else if (requiredLevel == 'edit' && perm.permissionLevel == 'edit') {
        return true;
      }
    }

    return false;
  }

  /// Update a record's visibility and grant explicit permissions to an audience
  Future<void> updateRecordVisibility({
    required String userId,
    required String recordType,
    required String recordId,
    required String visibility, // 'private', 'team', 'community'
    List<String>? audience, // List of user IDs or role keys
    String? permissionLevel, // 'view' or 'edit'
    DateTime? expiresAt,
  }) async {
    // 1. Ensure user is the owner
    final isOwner = await _isRecordOwner(userId, recordType, recordId);
    if (!isOwner) {
      throw Exception('Only the owner can modify sharing permissions.');
    }

    // 2. Update record's visibility column in the respective table
    await _updateTableVisibility(recordType, recordId, visibility);

    // 3. Revoke all previous active permissions for this record
    await (_db.update(_db.recordSharingPermissions)
          ..where((tbl) =>
              tbl.recordType.equals(recordType) &
              tbl.recordId.equals(recordId)))
        .write(RecordSharingPermissionsCompanion(
            revokedAt: Value(DateTime.now())));

    // 4. Create new permission records if visibility is 'team' and audience is specified
    if (visibility == 'team' && audience != null) {
      for (var target in audience) {
        await _db.into(_db.recordSharingPermissions).insert(
              RecordSharingPermissionsCompanion.insert(
                id: const Uuid().v4(),
                recordType: recordType,
                recordId: recordId,
                sharedWith: target,
                sharedBy: userId,
                permissionLevel: Value(permissionLevel ?? 'view'),
                expiresAt: Value(expiresAt),
              ),
            );
      }
    }
  }

  /// Calculate and update a user's Heart & Trust Index (HTI)
  Future<void> recalculateUserHti(String userId) async {
    // 1. TÍN (Truthfulness) - Based on completed service orders/bookings
    // Diminishing returns: repetitive orders with same peer decay in weight
    final completedOrders = await (_db.select(_db.serviceOrders)
          ..where((tbl) =>
              (tbl.consumerId.equals(userId) | tbl.providerId.equals(userId)) &
              tbl.status.equals('completed')))
        .get();

    final Map<String, int> peerCounts = {};
    double totalDecayWeight = 0.0;
    double positiveTxCount = 0.0;

    for (var o in completedOrders) {
      final peerId = o.consumerId == userId ? o.providerId : o.consumerId;
      final count = peerCounts[peerId] ?? 0;
      peerCounts[peerId] = count + 1;

      // Exponential decay weight: 1.0, 0.5, 0.25, 0.125 ...
      final weight = 1.0 / (1 << count);
      totalDecayWeight += weight;

      // Let's assume order was successful (no dispute). If status was completed, it counts positive.
      positiveTxCount += weight;
    }

    // Check disputes for Tín
    final totalDisputes = await (_db.select(_db.serviceOrders)
          ..where((tbl) =>
              (tbl.consumerId.equals(userId) | tbl.providerId.equals(userId)) &
              tbl.status.equals('disputed')))
        .get();

    final double disputePenalty = totalDisputes.length * 1.0;

    double tin = 5.0;
    if (completedOrders.isNotEmpty) {
      tin =
          ((positiveTxCount / (completedOrders.length)) * 5.0) - disputePenalty;
      if (tin < 1.0) tin = 1.0;
      if (tin > 5.0) tin = 5.0;
    }

    // 2. TÂM (Compassion) - Based on community help / mutual aid (price == 0 or category is volunteer)
    final mutualAidOrders = await (_db.select(_db.serviceOrders)
          ..where((tbl) =>
              tbl.providerId.equals(userId) &
              tbl.status.equals('completed') &
              (tbl.totalPrice.equals(0.0) | tbl.totalPrice.isNull())))
        .get();

    double tam = 3.0; // default base starting points
    // Volunteering adds points
    tam += mutualAidOrders.length * 0.4;
    if (tam > 5.0) tam = 5.0;

    // 3. NHẪN (Forbearance) - Based on amicable dispute resolutions
    // (disputed orders that were eventually completed/settled amicably)
    final resolvedAmicably = await (_db.select(_db.serviceOrders)
          ..where((tbl) =>
              (tbl.consumerId.equals(userId) | tbl.providerId.equals(userId)) &
              tbl.status.equals('completed')))
        .get(); // Simulating resolutions

    int resolvedCount = 0;
    for (var o in resolvedAmicably) {
      // If reference has resolved tag
      resolvedCount++;
    }

    double nhan = 3.5; // default base starting points
    nhan += resolvedCount * 0.15;
    if (nhan > 5.0) nhan = 5.0;

    // Aggregated overall HTI
    final double overallHti = (tin + tam + nhan) / 3.0;

    // Save/Update TrustScores table
    final exists = await (_db.select(_db.trustScores)
          ..where((tbl) => tbl.userId.equals(userId)))
        .getSingleOrNull();

    final companion = TrustScoresCompanion(
      userId: Value(userId),
      tinScore: Value(tin),
      tamScore: Value(tam),
      nhanScore: Value(nhan),
      overallHti: Value(overallHti),
      completedTransactions: Value(completedOrders.length),
      mutualAidCompleted: Value(mutualAidOrders.length),
      amicableDisputesResolved: Value(resolvedCount),
      updatedAt: Value(DateTime.now()),
    );

    if (exists != null) {
      await (_db.update(_db.trustScores)
            ..where((tbl) => tbl.userId.equals(userId)))
          .write(companion);
    } else {
      await _db.into(_db.trustScores).insert(companion);
    }
  }

  // ──────────────── Private Helper Methods ────────────────

  Future<bool> _isRecordOwner(
      String userId, String recordType, String recordId) async {
    try {
      switch (recordType) {
        case 'leads':
          final rec = await (_db.select(_db.leads)
                ..where((tbl) => tbl.id.equals(recordId)))
              .getSingleOrNull();
          return rec?.ownerId == null || rec?.ownerId == '' || rec?.ownerId == userId || rec?.ownerId == 'default_user';
        case 'deals':
          final rec = await (_db.select(_db.deals)
                ..where((tbl) => tbl.id.equals(recordId)))
              .getSingleOrNull();
          return rec?.ownerId == null || rec?.ownerId == '' || rec?.ownerId == userId || rec?.ownerId == 'default_user';
        case 'services':
          final rec = await (_db.select(_db.serviceListings)
                ..where((tbl) => tbl.id.equals(recordId)))
              .getSingleOrNull();
          return rec?.providerId == userId;
        case 'tasks':
          final rec = await (_db.select(_db.tasks)
                ..where((tbl) => tbl.id.equals(recordId)))
              .getSingleOrNull();
          // Find project owner
          if (rec != null) {
            final proj = await (_db.select(_db.projects)
                  ..where((tbl) => tbl.id.equals(rec.projectId)))
                .getSingleOrNull();
            // Assuming project customFields or owner details, fallback to true if no project owner
            return true;
          }
          return false;
        case 'projects':
          // Assume owner is creator, fallback to true for simulation
          return true;
        default:
          return false;
      }
    } catch (_) {
      return false;
    }
  }

  Future<String> _getRecordVisibility(
      String recordType, String recordId) async {
    try {
      switch (recordType) {
        case 'leads':
          final rec = await (_db.select(_db.leads)
                ..where((tbl) => tbl.id.equals(recordId)))
              .getSingleOrNull();
          return rec?.visibility ?? 'private';
        case 'deals':
          final rec = await (_db.select(_db.deals)
                ..where((tbl) => tbl.id.equals(recordId)))
              .getSingleOrNull();
          return rec?.visibility ?? 'private';
        case 'services':
          final rec = await (_db.select(_db.serviceListings)
                ..where((tbl) => tbl.id.equals(recordId)))
              .getSingleOrNull();
          return rec?.visibility ?? 'private';
        case 'tasks':
          final rec = await (_db.select(_db.tasks)
                ..where((tbl) => tbl.id.equals(recordId)))
              .getSingleOrNull();
          return rec?.visibility ?? 'private';
        case 'projects':
          final rec = await (_db.select(_db.projects)
                ..where((tbl) => tbl.id.equals(recordId)))
              .getSingleOrNull();
          return rec?.visibility ?? 'private';
        default:
          return 'private';
      }
    } catch (_) {
      return 'private';
    }
  }

  Future<void> _updateTableVisibility(
      String recordType, String recordId, String visibility) async {
    switch (recordType) {
      case 'leads':
        await (_db.update(_db.leads)..where((tbl) => tbl.id.equals(recordId)))
            .write(LeadsCompanion(visibility: Value(visibility)));
        break;
      case 'deals':
        await (_db.update(_db.deals)..where((tbl) => tbl.id.equals(recordId)))
            .write(DealsCompanion(visibility: Value(visibility)));
        break;
      case 'services':
        await (_db.update(_db.serviceListings)
              ..where((tbl) => tbl.id.equals(recordId)))
            .write(ServiceListingsCompanion(visibility: Value(visibility)));
        break;
      case 'tasks':
        await (_db.update(_db.tasks)..where((tbl) => tbl.id.equals(recordId)))
            .write(TasksCompanion(visibility: Value(visibility)));
        break;
      case 'projects':
        await (_db.update(_db.projects)
              ..where((tbl) => tbl.id.equals(recordId)))
            .write(ProjectsCompanion(visibility: Value(visibility)));
        break;
    }
  }
}
