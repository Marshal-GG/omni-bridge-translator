import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:url_launcher/url_launcher.dart';

enum SubscriptionTier { free, weekly, plus, pro }

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
}

class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  final _statusController = StreamController<SubscriptionStatus>.broadcast();
  Stream<SubscriptionStatus> get statusStream => _statusController.stream;

  SubscriptionStatus? _currentStatus;
  SubscriptionStatus? get currentStatus => _currentStatus;

  StreamSubscription? _userSub;

  void init() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _userSub?.cancel();
      if (user != null) {
        _listenToUserDoc(user.uid);
      } else {
        _currentStatus = null;
        _statusController.add(_getDefaultStatus());
      }
    });
  }

  void _listenToUserDoc(String uid) {
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
          if (!doc.exists) {
            _initializeUserDoc(uid);
            return;
          }

          final data = doc.data()!;
          final tierStr = data['tier'] as String? ?? 'free';
          final tier = _parseTier(tierStr);
          final charsUsed = data['dailyCharsUsed'] as int? ?? 0;
          final resetAt =
              (data['dailyResetAt'] as Timestamp?)?.toDate() ??
              _getNextResetTime();

          // Check if we need to reset quota (it's a new day)
          if (DateTime.now().isAfter(resetAt)) {
            _resetQuota(uid);
            return;
          }

          _currentStatus = SubscriptionStatus(
            tier: tier,
            dailyCharsUsed: charsUsed,
            dailyLimit: _getLimitForTier(tier),
            dailyResetAt: resetAt,
          );
          _statusController.add(_currentStatus!);
        });
  }

  Future<void> _initializeUserDoc(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'tier': 'free',
      'dailyCharsUsed': 0,
      'dailyResetAt': Timestamp.fromDate(_getNextResetTime()),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _resetQuota(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'dailyCharsUsed': 0,
      'dailyResetAt': Timestamp.fromDate(_getNextResetTime()),
    });
  }

  DateTime _getNextResetTime() {
    final now = DateTime.now();
    // Reset at midnight IST (UTC+5:30)
    // For simplicity, reset every 24 hours from current time if not set,
    // real implementation would align to midnight IST.
    return DateTime(now.year, now.month, now.day + 1);
  }

  SubscriptionTier _parseTier(String tier) {
    switch (tier.toLowerCase()) {
      case 'weekly':
        return SubscriptionTier.weekly;
      case 'plus':
        return SubscriptionTier.plus;
      case 'pro':
        return SubscriptionTier.pro;
      default:
        return SubscriptionTier.free;
    }
  }

  int _getLimitForTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.weekly:
        return 50000;
      case SubscriptionTier.plus:
        return 100000;
      case SubscriptionTier.pro:
        return 999999999; // Effectively unlimited
      default:
        return 10000;
    }
  }

  SubscriptionStatus _getDefaultStatus() {
    return SubscriptionStatus(
      tier: SubscriptionTier.free,
      dailyCharsUsed: 0,
      dailyLimit: 10000,
      dailyResetAt: _getNextResetTime(),
    );
  }

  Future<void> incrementChars(int count) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'dailyCharsUsed': FieldValue.increment(count),
    });
  }

  Future<void> openCheckout(SubscriptionTier tier) async {
    // Razorpay payment link placeholder
    // In production, these would be your real Razorpay Payment Links or a custom cloud function URL
    final String url = tier == SubscriptionTier.pro
        ? 'https://razorpay.me/@omnibridgepro'
        : tier == SubscriptionTier.plus
        ? 'https://razorpay.me/@omnibridgeplus'
        : 'https://razorpay.me/@omnibridgeweekly';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void dispose() {
    _userSub?.cancel();
    _statusController.close();
  }
}
