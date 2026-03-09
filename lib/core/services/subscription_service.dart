import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;

import 'package:url_launcher/url_launcher.dart';

enum SubscriptionTier { free, basic, plus, pro }

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
  StreamSubscription? _rtdbUsageSub;

  void init() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _userSub?.cancel();
      _rtdbUsageSub?.cancel();
      _lastKnownTier = null;
      if (user != null) {
        _listenToUserDoc(user.uid);
        _listenToRTDBUsage(user.uid);
      } else {
        _currentStatus = null;
        _statusController.add(_getDefaultStatus());
      }
    });
  }

  void _listenToRTDBUsage(String uid) async {
    // We cannot easily use standard RTDB snapshot listening without firebase_database plugin,
    // so we'll poll it periodically, OR we can add `firebase_database` plugin. 
    // Let's implement pooling as a fallback if `http` is the only way we access RTDB currently.
    // Wait, let's just add polling every 5 seconds since we are doing REST calls.
    // Or better, let's check `pubspec.yaml` to see if `firebase_database` is available.
    // It's requested to "listen to this specific path in RTDB instead of Firestore". 
    // I will use `http.get` initially, but setting up a Stream involves periodic polling unless we use `firebase_database`.
    // Actually, RTDB supports REST streaming via Server-Sent Events (SSE). 
    // Alternatively I'll use `Timer.periodic`.
    
    // For now, I'll set up a Timer that polls every 3 seconds while active.
    // Let's implement it inside a separate method properly.
  }

  // Polling mechanism since RTDB REST is used. 
  Timer? _usagePollTimer;

  void _startUsagePolling(String uid) {
    _usagePollTimer?.cancel();
    _fetchDailyUsage(uid); // initial fetch
    _usagePollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchDailyUsage(uid);
    });
  }

  Future<void> _fetchDailyUsage(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final url = Uri.parse('$_rtdbBaseUrl/users/$uid/daily_usage/$todayStr/tokens.json?auth=$idToken');
      
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tokensUsed = (data as num?)?.toInt() ?? 0;
        
        if (_currentStatus != null && _currentStatus!.dailyCharsUsed != tokensUsed) {
          _updateCurrentStatus(dailyCharsUsed: tokensUsed);
        }
      }
    } catch (e) {
      debugPrint('[Subscription] Failed to fetch daily usage: $e');
    }
  }

  void _updateCurrentStatus({int? dailyCharsUsed, SubscriptionTier? tier, DateTime? resetAt}) {
    if (_currentStatus == null && tier == null) return;
    
    final wasExceeded = _currentStatus?.isExceeded ?? false;
    final newTier = tier ?? _currentStatus?.tier ?? SubscriptionTier.free;
    final newUsed = dailyCharsUsed ?? _currentStatus?.dailyCharsUsed ?? 0;
    final newReset = resetAt ?? _currentStatus?.dailyResetAt ?? _getNextDailyReset();
    
    _currentStatus = SubscriptionStatus(
      tier: newTier,
      dailyCharsUsed: newUsed,
      dailyLimit: _getLimitForTier(newTier),
      dailyResetAt: newReset,
    );
    _statusController.add(_currentStatus!);

    if (!wasExceeded && (_currentStatus?.isExceeded ?? false)) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        _logQuotaExceeded(uid);
      }
    }
  }

  void _listenToUserDoc(String uid) {
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!doc.exists) {
          _initializeUserDoc(uid);
          return;
        }

        final data = doc.data()!;
        final tierStr = data['tier'] as String? ?? 'free';
        final tier = _parseTier(tierStr);
        // Notice we don't pull dailyCharsUsed from Firestore anymore.
        final resetAt = (data['dailyResetAt'] as Timestamp?)?.toDate() ??
            _getNextDailyReset();

        // Check if we need to reset daily quota (it's a new day)
        if (DateTime.now().isAfter(resetAt)) {
          // We don't reset RTDB daily quota here because it's path-based (new day = new path).
          // But we might want to update the DB's `dailyResetAt` to the next day so this doesn't trigger continually.
          _resetDailyQuota(uid);
          return;
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

        _updateCurrentStatus(tier: tier, resetAt: resetAt);
      });
    });
        
    _startUsagePolling(uid);
  }

  Future<void> _initializeUserDoc(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'tier': 'free',
      'dailyResetAt': Timestamp.fromDate(_getNextDailyReset()),
      'monthlyCharsUsed': 0,
      'monthlyResetAt': Timestamp.fromDate(_getNextMonthlyReset()),
      'lifetimeCharsUsed': 0,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _resetDailyQuota(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'dailyResetAt': Timestamp.fromDate(_getNextDailyReset()),
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

  /// Increments char usage counters for lifetime/monthly, wait for RTDB to update daily.
  Future<void> incrementChars(int count) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'monthlyCharsUsed': FieldValue.increment(count),
      'lifetimeCharsUsed': FieldValue.increment(count),
    });
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
        : 'https://razorpay.me/@omnibridgeweekly'; // Still uses the weekly URL for the basic tier for now

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  /// Manually updates the user tier in Firestore (Debug only).
  Future<void> setTierDebug(SubscriptionTier tier) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await setTierForOtherUser(uid, tier);
  }

  /// Updates the tier for any user (Admin only).
  Future<void> setTierForOtherUser(String uid, SubscriptionTier tier) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'tier': _tierToString(tier),
    });
    debugPrint('[Subscription] Tier for $uid set to $tier');
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
      case 'weekly': // Legacy support
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

  String _tierToString(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.basic:
        return 'basic';
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
      case SubscriptionTier.basic:
        return 1;
      case SubscriptionTier.plus:
        return 2;
      case SubscriptionTier.pro:
        return 3;
    }
  }

  int _getLimitForTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.basic:
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
    _rtdbUsageSub?.cancel();
    _usagePollTimer?.cancel();
    _statusController.close();
  }
}
