import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

  static const String _rtdbBaseUrl =
      'https://omni-bridge-ai-translator-default-rtdb.firebaseio.com';

  final _statusController = StreamController<SubscriptionStatus>.broadcast();
  Stream<SubscriptionStatus> get statusStream => _statusController.stream;

  SubscriptionStatus? _currentStatus;
  SubscriptionStatus? get currentStatus => _currentStatus;

  // Tracks current tier to detect upgrade/downgrade events
  SubscriptionTier? _lastKnownTier;

  StreamSubscription? _userSub;

  void init() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _userSub?.cancel();
      _lastKnownTier = null;
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
              _getNextDailyReset();

          // Check if we need to reset daily quota (it's a new day)
          if (DateTime.now().isAfter(resetAt)) {
            _resetDailyQuota(uid);
            return;
          }

          // Check if we need to reset monthly quota
          final monthlyResetAt =
              (data['monthlyResetAt'] as Timestamp?)?.toDate();
          if (monthlyResetAt != null && DateTime.now().isAfter(monthlyResetAt)) {
            _resetMonthlyQuota(uid);
          }

          // Detect tier change and log a subscription event
          if (_lastKnownTier != null && _lastKnownTier != tier) {
            _logSubscriptionEvent(
              uid: uid,
              fromTier: _lastKnownTier!,
              toTier: tier,
            );
          }
          _lastKnownTier = tier;

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
      'dailyResetAt': Timestamp.fromDate(_getNextDailyReset()),
      'monthlyCharsUsed': 0,
      'monthlyResetAt': Timestamp.fromDate(_getNextMonthlyReset()),
      'lifetimeCharsUsed': 0,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _resetDailyQuota(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'dailyCharsUsed': 0,
      'dailyResetAt': Timestamp.fromDate(_getNextDailyReset()),
    });
  }

  Future<void> _resetMonthlyQuota(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'monthlyCharsUsed': 0,
      'monthlyResetAt': Timestamp.fromDate(_getNextMonthlyReset()),
    });
  }

  /// Logs a tier change event to the `subscription_events` sub-collection.
  Future<void> _logSubscriptionEvent({
    required String uid,
    required SubscriptionTier fromTier,
    required SubscriptionTier toTier,
  }) async {
    final isUpgrade = _tierRank(toTier) > _tierRank(fromTier);
    final event = isUpgrade ? 'upgraded' : 'downgraded';

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('subscription_events')
          .add({
            'event': event,
            'from': _tierToString(fromTier),
            'to': _tierToString(toTier),
            'timestamp': FieldValue.serverTimestamp(),
            'via': 'razorpay',
          });

      // On first upgrade from free, record subscriptionSince + paymentProvider
      if (fromTier == SubscriptionTier.free && isUpgrade) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'subscriptionSince': FieldValue.serverTimestamp(),
              'paymentProvider': 'razorpay',
            });
      }

      debugPrint('[Subscription] Event logged: $event ($fromTier → $toTier)');
    } catch (e) {
      debugPrint('[Subscription] Failed to log subscription event: $e');
    }
  }

  /// Increments char usage counters and handles quota-exceeded logging.
  Future<void> incrementChars(int count) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final wasExceeded = _currentStatus?.isExceeded ?? false;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'dailyCharsUsed': FieldValue.increment(count),
      'monthlyCharsUsed': FieldValue.increment(count),
      'lifetimeCharsUsed': FieldValue.increment(count),
    });

    // Log quota breach event (only on the crossing, not every subsequent call)
    if (!wasExceeded && (_currentStatus?.isExceeded ?? false)) {
      _logQuotaExceeded(uid);
    }
  }

  /// Logs a quota_exceeded event to RTDB and updates `lastQuotaExceededAt`.
  Future<void> _logQuotaExceeded(String uid) async {
    try {
      // Update Firestore timestamp
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'lastQuotaExceededAt': FieldValue.serverTimestamp(),
      });

      // Log to RTDB so it appears in the event stream alongside other app events
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();
      final url = Uri.parse(
        '$_rtdbBaseUrl/users/$uid/logs.json?auth=$idToken',
      );
      await http.post(
        url,
        body: jsonEncode({
          'event': 'quota_exceeded',
          'data': {
            'tier': _tierToString(_currentStatus?.tier ?? SubscriptionTier.free),
            'dailyLimit': _currentStatus?.dailyLimit ?? 0,
            'dailyCharsUsed': _currentStatus?.dailyCharsUsed ?? 0,
          },
          'timestamp': {'.sv': 'timestamp'},
        }),
      );
      debugPrint('[Subscription] Quota exceeded event logged.');
    } catch (e) {
      debugPrint('[Subscription] Failed to log quota exceeded: $e');
    }
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

  // ── Helpers ────────────────────────────────────────────────────────────────

  DateTime _getNextDailyReset() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }

  DateTime _getNextMonthlyReset() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 1);
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

  String _tierToString(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.weekly:
        return 'weekly';
      case SubscriptionTier.plus:
        return 'plus';
      case SubscriptionTier.pro:
        return 'pro';
      default:
        return 'free';
    }
  }

  int _tierRank(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return 0;
      case SubscriptionTier.weekly:
        return 1;
      case SubscriptionTier.plus:
        return 2;
      case SubscriptionTier.pro:
        return 3;
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
      dailyResetAt: _getNextDailyReset(),
    );
  }

  void dispose() {
    _userSub?.cancel();
    _statusController.close();
  }
}
