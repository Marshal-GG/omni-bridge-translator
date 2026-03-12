import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'package:url_launcher/url_launcher.dart';

import 'package:omni_bridge/models/subscription_models.dart';

class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  static final String _appName = kDebugMode ? 'OmniBridge-Debug' : 'OmniBridge-Release';
  FirebaseApp get _app => Firebase.app(_appName);
  FirebaseAuth get _auth => FirebaseAuth.instanceFor(app: _app);
  FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(app: _app);

  static const String _rtdbBaseUrl =
      'https://omni-bridge-ai-translator-default-rtdb.firebaseio.com';

  // --- Dynamic Monetization Config ---
  Map<String, dynamic>? _monetizationConfig;
  StreamSubscription? _monetizationSub;

  final http.Client _httpClient = http.Client();

  final _statusController = StreamController<SubscriptionStatus>.broadcast();
  Stream<SubscriptionStatus> get statusStream => _statusController.stream;

  SubscriptionStatus? _currentStatus;
  SubscriptionStatus? get currentStatus => _currentStatus;

  // Tracks current tier to detect upgrade/downgrade events
  String? _lastKnownTier;

  StreamSubscription? _userSub;
  StreamSubscription? _rtdbUsageSub;

  void init() {
    _listenToMonetizationConfig();
    _auth.authStateChanges().listen((user) {
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

  void _listenToMonetizationConfig() {
    _monetizationSub?.cancel();
    _monetizationSub = _firestore
        .collection('system')
        .doc('monetization')
        .snapshots()
        .listen((doc) {
          if (doc.exists) {
            _monetizationConfig = doc.data();
            debugPrint(
              '[Subscription] Monetization config updated from Firestore',
            );

            // Refresh current status if we have one to apply new limits
            if (_currentStatus != null) {
              _updateCurrentStatus();
            }
          }
        });
  }

  void _listenToRTDBUsage(String uid) async {
    _startUsagePolling(uid);
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

  Future<void> _fetchDailyUsage(String uid, {int retryCount = 0}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final url = Uri.parse(
        '$_rtdbBaseUrl/users/$uid/daily_usage/$todayStr/tokens.json?auth=$idToken',
      );

      final response = await _httpClient
          .get(url)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tokensUsed = (data as num?)?.toInt() ?? 0;

        if (_currentStatus != null &&
            _currentStatus!.dailyTokensUsed != tokensUsed) {
          _updateCurrentStatus(dailyTokensUsed: tokensUsed);
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Auth error, might need token refresh but we'll let the next poll handle it
        debugPrint('[Subscription] RTDB fetch auth error: ${response.statusCode}');
      }
    } on TimeoutException {
      debugPrint('[Subscription] RTDB usage fetch timed out.');
    } catch (e) {
      if (retryCount < 3 && (e.toString().contains('Connection closed') || e.toString().contains('ClientException'))) {
        final delay = Duration(milliseconds: 500 * (retryCount + 1));
        debugPrint('[Subscription] RTDB fetch failed ($e), retrying in ${delay.inMilliseconds}ms... (Attempt ${retryCount + 1})');
        await Future.delayed(delay);
        return _fetchDailyUsage(uid, retryCount: retryCount + 1);
      }
      debugPrint('[Subscription] Failed to fetch daily usage after retries: $e');
    }
  }

  void _updateCurrentStatus({
    int? dailyTokensUsed,
    String? tier,
    DateTime? resetAt,
  }) {
    if (_currentStatus == null && tier == null) return;

    final wasExceeded = _currentStatus?.isExceeded ?? false;
    final newTier = tier ?? _currentStatus?.tier ?? defaultTier;
    final newUsed = dailyTokensUsed ?? _currentStatus?.dailyTokensUsed ?? 0;
    final newReset =
        resetAt ?? _currentStatus?.dailyResetAt ?? _getNextDailyReset();

    _currentStatus = SubscriptionStatus(
      tier: newTier,
      dailyTokensUsed: newUsed,
      dailyLimit: _getLimitForTier(newTier),
      dailyResetAt: newReset,
    );
    _statusController.add(_currentStatus!);

    if (!wasExceeded && (_currentStatus?.isExceeded ?? false)) {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        _logQuotaExceeded(uid);
      }
    }
  }

  void _listenToUserDoc(String uid) {
    _userSub = _firestore
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
            final tierStr = data['tier'] as String? ?? defaultTier;
            final tier = tierStr;
            // Notice we don't pull dailyTokensUsed from Firestore anymore.
            final resetAt =
                (data['dailyResetAt'] as Timestamp?)?.toDate() ??
                _getNextDailyReset();

            // Check if we need to reset daily quota (it's a new day)
            if (DateTime.now().isAfter(resetAt)) {
              // We don't reset RTDB daily quota here because it's path-based (new day = new path).
              // But we might want to update the DB's `dailyResetAt` to the next day so this doesn't trigger continually.
              _resetDailyQuota(uid);
              return;
            }

            // Check if we need to reset monthly quota
            final monthlyResetAt =
                (data['monthlyResetAt'] as Timestamp?)?.toDate();
            if (monthlyResetAt != null &&
                DateTime.now().isAfter(monthlyResetAt)) {
              _resetMonthlyQuota(uid);
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
  }

  Future<void> _initializeUserDoc(String uid) async {
    await _firestore.collection('users').doc(uid).set({
      'tier': defaultTier,
      'dailyResetAt': Timestamp.fromDate(_getNextDailyReset()),
      'monthlyTokensUsed': 0,
      'monthlyResetAt': Timestamp.fromDate(_getNextMonthlyReset()),
      'lifetimeTokensUsed': 0,
      'forceLogout': false,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _resetDailyQuota(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'dailyResetAt': Timestamp.fromDate(_getNextDailyReset()),
    });
  }

  /// Resets the monthly token counter and advances monthlyResetAt by 30 days
  /// (rolling billing-cycle reset, not calendar-month reset).
  Future<void> _resetMonthlyQuota(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'monthlyTokensUsed': 0,
      'monthlyResetAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
    });
    debugPrint('[Subscription] Monthly quota reset for $uid');
  }

  /// Logs a tier change event to the `subscription_events` sub-collection.
  Future<void> _logSubscriptionEvent({
    required String uid,
    required String fromTier,
    required String toTier,
  }) async {
    final isUpgrade = getTierRank(toTier) > getTierRank(fromTier);
    final event = isUpgrade ? 'upgraded' : 'downgraded';

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('subscription_events')
          .add({
            'event': event,
            'from': fromTier,
            'to': toTier,
            'timestamp': FieldValue.serverTimestamp(),
            'via': 'razorpay',
          });

      // On first upgrade from free, record subscriptionSince + paymentProvider
      // and anchor the billing-cycle monthly reset to 30 days from now.
      if (fromTier == defaultTier && isUpgrade) {
        await _firestore.collection('users').doc(uid).update({
          'subscriptionSince': FieldValue.serverTimestamp(),
          'paymentProvider': 'razorpay',
          'monthlyTokensUsed': 0,
          'monthlyResetAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30)),
          ),
        });
      }

      debugPrint('[Subscription] Event logged: $event ($fromTier → $toTier)');
    } catch (e) {
      debugPrint('[Subscription] Failed to log subscription event: $e');
    }
  }

  /// Increments token usage counters for lifetime/monthly, wait for RTDB to update daily.
  Future<void> incrementTokens(int count) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).update({
      'monthlyTokensUsed': FieldValue.increment(count),
      'lifetimeTokensUsed': FieldValue.increment(count),
    });
  }

  /// Logs a quota_exceeded event to RTDB and updates `lastQuotaExceededAt`.
  Future<void> _logQuotaExceeded(String uid) async {
    try {
      // Update Firestore timestamp
      await _firestore.collection('users').doc(uid).update({
        'lastQuotaExceededAt': FieldValue.serverTimestamp(),
      });

      // Log to RTDB so it appears in the event stream alongside other app events
      final user = _auth.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();
      final url = Uri.parse('$_rtdbBaseUrl/users/$uid/logs.json?auth=$idToken');
      await _httpClient
          .post(
            url,
            body: jsonEncode({
              'event': 'quota_exceeded',
              'data': {
                'tier': _currentStatus?.tier ?? defaultTier,

                'dailyLimit': _currentStatus?.dailyLimit ?? 0,
                'dailyTokensUsed': _currentStatus?.dailyTokensUsed ?? 0,
              },
              'timestamp': {'.sv': 'timestamp'},
            }),
          )
          .timeout(const Duration(seconds: 5));
      debugPrint('[Subscription] Quota exceeded event logged.');
    } on TimeoutException {
      debugPrint('[Subscription] Quota exceeded log timed out.');
    } catch (e) {
      debugPrint('[Subscription] Failed to log quota exceeded: $e');
    }
  }

  Future<void> openCheckout(String tierId) async {
    final config =
        _monetizationConfig?['payment_links'] as Map<String, dynamic>?;

    final String? url = config?[tierId] as String?;

    if (url != null && await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      debugPrint('[Subscription] No payment link found for tier: $tierId');
    }
  }

  /// Manually updates the user tier in Firestore (Debug only).
  Future<void> setTierDebug(String tier) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await setTierForOtherUser(uid, tier);
  }

  /// Updates the tier for any user (Admin only).
  Future<void> setTierForOtherUser(String uid, String tier) async {
    await _firestore.collection('users').doc(uid).update({
      'tier': tier,
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

  /// Returns the dynamically determined default (fallback) tier
  String get defaultTier {
    final order = _monetizationConfig?['order'] as List<dynamic>? ?? [];
    return order.isNotEmpty ? order.first.toString() : '';
  }

  /// Returns true if the tier is the highest available tier
  bool isHighestTier(String tier) {
    final order = _monetizationConfig?['order'] as List<dynamic>? ?? [];
    if (order.isEmpty) return false;
    return order.last.toString() == tier;
  }

  /// Returns the tier mapped to the given index order
  String getTierAt(int index) {
    final order = _monetizationConfig?['order'] as List<dynamic>? ?? [];
    if (order.isEmpty) return '';
    if (index < 0) return order.first.toString();
    if (index >= order.length) return order.last.toString();
    return order[index].toString();
  }

  /// Returns the display name for a tier at a given rank index.
  String getNameForRank(int rank) {
    return getNameForTier(getTierAt(rank));
  }

  int getTierRank(String tier) {
    if (tier == defaultTier) return 0;
    final order = _monetizationConfig?['order'] as List<dynamic>? ?? [];
    if (order.contains(tier)) {
      return order.indexOf(tier);
    }
    return 0;
  }

  bool tierHasAccess(String currentTier, String requiredTier) {
    return getTierRank(currentTier) >= getTierRank(requiredTier);
  }

  int _getLimitForTier(String tier) {
    // Before monetization config loads, return safe defaults:
    // default tier gets 10,000 tokens, any paid tier gets -1 (unlimited flag)
    // so Pro users don't briefly flash as quota-exceeded on cold start.
    if (_monetizationConfig == null) {
      return tier == defaultTier ? 10000 : -1;
    }

    final limits = _monetizationConfig?['limits'] as Map<String, dynamic>?;
    return (limits?[tier] as num?)?.toInt() ?? 0;
  }

  /// Gets the price string for a tier from Firestore.
  String getPriceForTier(String tier) {
    final prices = _monetizationConfig?['prices'] as Map<String, dynamic>?;
    return prices?[tier] ?? '';
  }

  /// Gets the tier requirement for an engine or whisper size.
  String getRequirement(
    String category,
    String key,
    String fallback,
  ) {
    final requirements =
        _monetizationConfig?['requirements'] as Map<String, dynamic>?;
    if (requirements == null || !requirements.containsKey(category)) {
      return fallback;
    }

    final categoryMap = requirements[category] as Map<String, dynamic>;
    if (!categoryMap.containsKey(key)) return fallback;

    return categoryMap[key] as String;
  }

  /// Gets the display name for a tier from Firestore.
  String getNameForTier(String tier) {
    if (tier == defaultTier && defaultTier.isEmpty) return 'Free';
    final names = _monetizationConfig?['names'] as Map<String, dynamic>?;
    return names?[tier] ?? tier.toUpperCase();
  }

  /// List of plans dynamically evaluated from _monetizationConfig
  List<SubscriptionPlan> get availablePlans {
    final order = _monetizationConfig?['order'] as List<dynamic>? ?? [];
    if (order.isEmpty) return [];

    final names = _monetizationConfig?['names'] as Map<String, dynamic>? ?? {};
    final prices = _monetizationConfig?['prices'] as Map<String, dynamic>? ?? {};
    final descriptions = _monetizationConfig?['descriptions'] as Map<String, dynamic>? ?? {};
    final featuresMap = _monetizationConfig?['features'] as Map<String, dynamic>? ?? {};
    final popular = _monetizationConfig?['popular'] as String? ?? '';

    return order.map((key) {
      final id = key.toString();
      return SubscriptionPlan(
        id: id,
        name: names[id]?.toString() ?? id.toUpperCase(),
        price: prices[id]?.toString() ?? '',
        description: descriptions[id]?.toString() ?? '',
        features:
            (featuresMap[id] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        isPopular: id == popular,
      );
    }).toList();
  }

  SubscriptionStatus _getDefaultStatus() {
    return SubscriptionStatus(
      tier: defaultTier,
      dailyTokensUsed: 0,
      dailyLimit: _getLimitForTier(defaultTier),
      dailyResetAt: _getNextDailyReset(),
    );
  }

  void dispose() {
    _monetizationSub?.cancel();
    _userSub?.cancel();
    _rtdbUsageSub?.cancel();
    _usagePollTimer?.cancel();
    _httpClient.close();
    _statusController.close();
  }
}
