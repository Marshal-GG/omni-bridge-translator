import 'package:equatable/equatable.dart';

class SystemSnapshot extends Equatable {
  final String osVersion;
  final String appVersion;
  final String subscriptionTier;
  final int remainingQuota;
  final String userEmail;

  const SystemSnapshot({
    required this.osVersion,
    required this.appVersion,
    required this.subscriptionTier,
    required this.remainingQuota,
    required this.userEmail,
  });

  Map<String, dynamic> toJson() {
    return {
      'os_version': osVersion,
      'app_version': appVersion,
      'subscription_tier': subscriptionTier,
      'remaining_quota': remainingQuota,
      'user_email': userEmail,
    };
  }

  factory SystemSnapshot.fromJson(Map<String, dynamic> json) {
    return SystemSnapshot(
      osVersion: json['os_version'] as String? ?? 'Unknown',
      appVersion: json['app_version'] as String? ?? 'Unknown',
      subscriptionTier: json['subscription_tier'] as String? ?? 'Free',
      remainingQuota: json['remaining_quota'] as int? ?? 0,
      userEmail: json['user_email'] as String? ?? 'anonymous',
    );
  }

  @override
  List<Object?> get props => [
    osVersion,
    appVersion,
    subscriptionTier,
    remainingQuota,
    userEmail,
  ];
}
