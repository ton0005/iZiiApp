class TrustScore {
  final String userId;
  final double overallScore; // 0.0 - 5.0
  final int referralCount;
  final String? referredBy;
  final int completedOrders;
  final double avgRating;
  final DateTime memberSince;
  final TrustLevel level;
  final bool kycVerified;

  TrustScore({
    required this.userId,
    this.overallScore = 0.0,
    this.referralCount = 0,
    this.referredBy,
    this.completedOrders = 0,
    this.avgRating = 0.0,
    required this.memberSince,
    this.level = TrustLevel.newcomer,
    this.kycVerified = false,
  });
}

enum TrustLevel { newcomer, trusted, verified, elite }

class Referral {
  final String id;
  final String inviterId;
  final String? inviteeId;
  final String contactInfo;
  final ReferralStatus status;
  final DateTime createdAt;

  Referral({
    required this.id,
    required this.inviterId,
    this.inviteeId,
    required this.contactInfo,
    this.status = ReferralStatus.sent,
    required this.createdAt,
  });
}

enum ReferralStatus { sent, accepted, expired }
