enum TrustLevel {
  baguhan(1, '🆕 Baguhan', 0),
  verified(1, '✅ Verified', 5),
  trusted(2, '⭐ Trusted', 20),
  bayani(3, '🛡️ Bayani', 50); // Need 50 reports, counts as 3 votes

  final int weight;
  final String badge;
  final int requiredReports;

  const TrustLevel(this.weight, this.badge, this.requiredReports);

  static TrustLevel fromReports(int reports) {
    if (reports >= bayani.requiredReports) return bayani;
    if (reports >= trusted.requiredReports) return trusted;
    if (reports >= verified.requiredReports) return verified;
    return baguhan;
  }
}

class UserTrust {
  final String userId;
  final int confirmedReports;

  UserTrust({
    required this.userId,
    this.confirmedReports = 0,
  });

  TrustLevel get level => TrustLevel.fromReports(confirmedReports);
  int get voteWeight => level.weight;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'confirmedReports': confirmedReports,
  };

  factory UserTrust.fromJson(Map<String, dynamic> json) => UserTrust(
    userId: json['userId'] ?? '',
    confirmedReports: json['confirmedReports'] ?? 0,
  );
}
