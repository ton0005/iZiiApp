import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../database/app_database.dart';
import 'models/community_models.dart' as community;
import 'trust_network_service.dart';

class InviteService {
  static final InviteService _instance = InviteService._internal();
  factory InviteService() => _instance;
  InviteService._internal();

  final _db = AppDatabase();

  Future<community.Referral> sendInvite(
      String inviterId, String contactInfo) async {
    final referralId = const Uuid().v4();

    await _db.into(_db.referrals).insert(ReferralsCompanion.insert(
          id: referralId,
          inviterId: inviterId,
          contactInfo: contactInfo,
        ));

    // TODO: Send actual SMS/Email here using third-party services

    return community.Referral(
      id: referralId,
      inviterId: inviterId,
      contactInfo: contactInfo,
      createdAt: DateTime.now(),
    );
  }

  Future<bool> acceptInvite(String referralId, String newUserId) async {
    final referrals = await _db.select(_db.referrals).get();
    final index = referrals.indexWhere((r) => r.id == referralId);

    if (index != -1) {
      final referral = referrals[index];

      if (referral.status != 'sent') {
        return false; // expired or already accepted
      }

      await _db.update(_db.referrals).replace(referral.copyWith(
            status: 'accepted',
            inviteeId: drift.Value(newUserId),
            acceptedAt: drift.Value(DateTime.now()),
          ));

      // Increment inviter's referral count
      final scores = await _db.select(_db.trustScores).get();
      try {
        final inviterScore =
            scores.firstWhere((s) => s.userId == referral.inviterId);
        await _db.update(_db.trustScores).replace(inviterScore.copyWith(
              referralCount: inviterScore.referralCount + 1,
            ));
        // Recalculate inviter score
        await TrustNetworkService().recalculateScore(referral.inviterId);
      } catch (e) {
        // Ignore if inviter score not found
      }

      return true;
    }

    return false;
  }

  Future<List<community.Referral>> getInvitesByUser(String userId) async {
    final referrals = await _db.select(_db.referrals).get();
    final userReferrals =
        referrals.where((r) => r.inviterId == userId).toList();

    return userReferrals
        .map((r) => community.Referral(
              id: r.id,
              inviterId: r.inviterId,
              inviteeId: r.inviteeId,
              contactInfo: r.contactInfo,
              status: community.ReferralStatus.values.firstWhere(
                (e) => e.name == r.status,
                orElse: () => community.ReferralStatus.sent,
              ),
              createdAt: r.createdAt,
            ))
        .toList();
  }

  String generateInviteLink(String userId) {
    return 'https://izii.app/invite/$userId';
  }
}
