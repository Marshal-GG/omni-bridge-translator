class SubscriptionStatus {
  final String tier;
  final int dailyTokensUsed;
  final int weeklyTokensUsed;
  final int monthlyTokensUsed;
  final int lifetimeTokensUsed;
  final int dailyLimit;
  final DateTime dailyResetAt;

  const SubscriptionStatus({
    required this.tier,
    required this.dailyTokensUsed,
    required this.weeklyTokensUsed,
    required this.monthlyTokensUsed,
    required this.lifetimeTokensUsed,
    required this.dailyLimit,
    required this.dailyResetAt,
  });

  bool get isUnlimited => dailyLimit < 0;
  double get progress => dailyLimit <= 0 ? 0 : dailyTokensUsed / dailyLimit;
  bool get isExceeded => !isUnlimited && dailyTokensUsed >= dailyLimit;

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      tier: json['tier'] as String? ?? '',
      dailyTokensUsed: json['dailyTokensUsed'] as int? ?? 0,
      weeklyTokensUsed: json['weeklyTokensUsed'] as int? ?? 0,
      monthlyTokensUsed: json['monthlyTokensUsed'] as int? ?? 0,
      lifetimeTokensUsed: json['lifetimeTokensUsed'] as int? ?? 0,
      dailyLimit: json['dailyLimit'] as int? ?? 0,
      dailyResetAt: json['dailyResetAt'] != null
          ? DateTime.parse(json['dailyResetAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tier': tier,
      'dailyTokensUsed': dailyTokensUsed,
      'weeklyTokensUsed': weeklyTokensUsed,
      'monthlyTokensUsed': monthlyTokensUsed,
      'lifetimeTokensUsed': lifetimeTokensUsed,
      'dailyLimit': dailyLimit,
      'dailyResetAt': dailyResetAt.toIso8601String(),
    };
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
