enum SubscriptionTier {
  free,
  basic,
  plus,
  pro;

  int get rank {
    switch (this) {
      case SubscriptionTier.free:
        return 0;
      case SubscriptionTier.basic:
        return 1;
      case SubscriptionTier.plus:
        return 2;
      case SubscriptionTier.pro:
        return 3;
    }
  }
}

class SubscriptionStatus {
  final SubscriptionTier tier;
  final int dailyCharsUsed;
  final int dailyLimit;
  final DateTime dailyResetAt;

  const SubscriptionStatus({
    required this.tier,
    required this.dailyCharsUsed,
    required this.dailyLimit,
    required this.dailyResetAt,
  });

  bool get isUnlimited => tier == SubscriptionTier.pro;
  double get progress => dailyLimit == 0 ? 0 : dailyCharsUsed / dailyLimit;
  bool get isExceeded => !isUnlimited && dailyCharsUsed >= dailyLimit;

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      tier: _parseTier(json['tier'] as String? ?? 'free'),
      dailyCharsUsed: json['dailyCharsUsed'] as int? ?? 0,
      dailyLimit: json['dailyLimit'] as int? ?? 0,
      dailyResetAt: json['dailyResetAt'] != null
          ? DateTime.parse(json['dailyResetAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tier': tier.name,
      'dailyCharsUsed': dailyCharsUsed,
      'dailyLimit': dailyLimit,
      'dailyResetAt': dailyResetAt.toIso8601String(),
    };
  }

  static SubscriptionTier _parseTier(String tier) {
    switch (tier.toLowerCase()) {
      case 'basic':
        return SubscriptionTier.basic;
      case 'plus':
        return SubscriptionTier.plus;
      case 'pro':
        return SubscriptionTier.pro;
      default:
        return SubscriptionTier.free;
    }
  }
}

class SubscriptionPlan {
  final String id;
  final String name;
  final String price;
  final String description;
  final List<String> features;
  final bool isPopular;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.features,
    this.isPopular = false,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      price: json['price'] as String,
      description: json['description'] as String,
      features: List<String>.from(json['features'] ?? []),
      isPopular: json['isPopular'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'features': features,
      'isPopular': isPopular,
    };
  }
}
