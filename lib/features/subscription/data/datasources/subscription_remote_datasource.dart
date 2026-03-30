import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:omni_bridge/features/subscription/data/models/subscription_dto.dart';

class SubscriptionRemoteDataSource {
  SubscriptionRemoteDataSource._();
  static final SubscriptionRemoteDataSource instance =
      SubscriptionRemoteDataSource._();

  static final String _appName = kDebugMode
      ? 'OmniBridge-Debug'
      : 'OmniBridge-Release';
  FirebaseApp get _app => Firebase.app(_appName);
  FirebaseAuth get _auth => FirebaseAuth.instanceFor(app: _app);
  FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(app: _app);
  static const String _rtdbBaseUrl =
      'https://omni-bridge-ai-translator-default-rtdb.firebaseio.com';

  // --- Dynamic Monetization Config ---
  Map<String, dynamic>? _monetizationConfig;
  StreamSubscription? _monetizationSub;

  /// Notifies listeners whenever the monetization config changes (plans become available).
  final configNotifier = ValueNotifier<int>(0);

  final http.Client _httpClient = http.Client();

  final _statusController = StreamController<SubscriptionStatus>.broadcast();
  Stream<SubscriptionStatus> get statusStream => _statusController.stream;

  SubscriptionStatus? _currentStatus;
  SubscriptionStatus? get currentStatus => _currentStatus;

  // Tracks current tier to detect upgrade/downgrade events
  String? _lastKnownTier;

  StreamSubscription? _userSub;
  Timer? _usagePollTimer;
  int? _currentPollInterval;

  void init() {
    _listenToMonetizationConfig();
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _lastKnownTier = null;
        _listenToUserDoc(user.uid);
        _listenToRTDBUsage(user.uid);
      } else {
        reset();
      }
    });
  }

  /// Resets the singleton state. Called on logout to prevent state leakage.
  void reset() {
    _userSub?.cancel();
    _userSub = null;
    _usagePollTimer?.cancel();
    _usagePollTimer = null;
    _lastKnownTier = null;
    _currentStatus = null;
    _statusController.add(_getDefaultStatus());
    debugPrint('[Subscription] SubscriptionRemoteDataSource state reset');
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
              '[Subscription] Monetization config updated. Keys: ${_monetizationConfig?.keys.toList()} - Interval: $pollIntervalSeconds',
            );
            // Always emit status so bloc/UI refreshes with the latest plans
            if (_currentStatus != null) {
              _updateCurrentStatus();
            } else {
              _statusController.add(_getDefaultStatus());
            }
            // Notify any ValueListenableBuilder widgets (e.g. admin panel)
            configNotifier.value++;
            _maybeRestartPolling();
          } else {
            debugPrint(
              '[Subscription] system/monetization document does NOT exist',
            );
          }
        });
  }

  /// Returns the usage polling interval from Firestore config, defaulting to 30s.
  int get pollIntervalSeconds {
    final raw = _monetizationConfig?['usage_poll_interval_seconds'];
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 30;
    return 30;
  }

  /// Returns caption retention days for the current tier from tiers config.
  int get captionRetentionDays {
    final tier = _currentStatus?.tier ?? defaultTier;
    final config = _tierConfig(tier);
    return (config?['features']?['caption_retention_days'] as num?)?.toInt() ??
        30;
  }

  // ── Tier Config Helpers ─────────────────────────────────────────────────

  /// Returns the full config map for a given tier from the `tiers` field.
  Map<String, dynamic>? _tierConfig(String tier) {
    final tiers = _monetizationConfig?['tiers'] as Map<String, dynamic>?;
    return tiers?[tier] as Map<String, dynamic>?;
  }

  /// Returns the allowed translation models for the current (or given) tier.
  List<String> allowedTranslationModels([String? tier]) {
    final t = tier ?? _currentStatus?.tier ?? defaultTier;
    final config = _tierConfig(t);
    final models = config?['allowed_translation_models'] as List<dynamic>?;
    return models?.cast<String>() ?? ['google', 'mymemory'];
  }

  /// Returns the allowed transcription models for the current (or given) tier.
  List<String> allowedTranscriptionModels([String? tier]) {
    final t = tier ?? _currentStatus?.tier ?? defaultTier;
    final config = _tierConfig(t);
    final models = config?['allowed_transcription_models'] as List<dynamic>?;
    return models?.cast<String>() ?? ['online'];
  }

  /// Whether a specific model is allowed for the current tier.
  bool isModelAllowed(String modelId) {
    return allowedTranslationModels().contains(modelId) ||
        allowedTranscriptionModels().contains(modelId);
  }

  /// Whether a model is globally enabled (kill switch).
  bool isModelEnabled(String modelId) {
    final overrides =
        _monetizationConfig?['model_overrides'] as Map<String, dynamic>?;
    if (overrides == null) return true;
    final model = overrides[modelId] as Map<String, dynamic>?;
    return model?['enabled'] as bool? ?? true;
  }

  /// Whether a model can be used: globally enabled AND allowed for current tier.
  bool canUseModel(String modelId) {
    return isModelEnabled(modelId) && isModelAllowed(modelId);
  }

  /// Returns per-engine monthly limits for the current (or given) tier.
  /// Engines not in this map have no per-engine cap (follow overall quotas only).
  Map<String, int> engineLimits([String? tier]) {
    final t = tier ?? _currentStatus?.tier ?? defaultTier;
    final config = _tierConfig(t);
    final raw = config?['engine_limits'] as Map<String, dynamic>? ?? {};
    return raw.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  /// Returns the monthly limit for a specific engine, or -1 if no per-engine cap.
  int engineMonthlyLimit(String engineId, [String? tier]) {
    final limits = engineLimits(tier);
    return limits[engineId] ?? -1;
  }

  /// Returns the fallback engine for when a paid engine's limit is exceeded.
  /// Reads from system/monetization → fallback_engine, defaults to 'google'.
  String get fallbackEngine =>
      _monetizationConfig?['fallback_engine'] as String? ?? 'google';

  /// Returns the display name for a model/engine ID.
  /// Reads from system/monetization → model_overrides → {id} → display_name.
  String getModelDisplayName(String engineId) {
    final overrides =
        _monetizationConfig?['model_overrides'] as Map<String, dynamic>?;
    final entry = overrides?[engineId] as Map<String, dynamic>?;
    return entry?['display_name'] as String? ?? engineId;
  }

  /// Returns the features map for the current tier.
  Map<String, dynamic> get tierFeatures {
    final tier = _currentStatus?.tier ?? defaultTier;
    final config = _tierConfig(tier);
    return (config?['features'] as Map<String, dynamic>?) ?? {};
  }

  /// Returns the current announcement config (if active).
  Map<String, dynamic>? get activeAnnouncement {
    final ann = _monetizationConfig?['announcements'] as Map<String, dynamic>?;
    if (ann == null || ann['active'] != true) return null;
    final targetTiers = ann['target_tiers'] as List<dynamic>?;
    final currentTier = _currentStatus?.tier ?? defaultTier;
    if (targetTiers != null && !targetTiers.contains(currentTier)) return null;
    return ann;
  }

  /// Returns the app version control config.
  Map<String, dynamic>? get appVersionConfig {
    return _monetizationConfig?['app_version'] as Map<String, dynamic>?;
  }

  /// Returns the upgrade prompt config.
  Map<String, dynamic>? get upgradePromptConfig {
    return _monetizationConfig?['upgrade_prompts'] as Map<String, dynamic>?;
  }

  /// Restarts the polling timer if the configured interval has changed.
  void _maybeRestartPolling() {
    final newInterval = pollIntervalSeconds;
    if (_currentPollInterval == newInterval) return;
    final user = _auth.currentUser;
    if (user == null) return;

    _currentPollInterval = newInterval;
    debugPrint(
      '[Subscription] Poll interval changed to ${newInterval}s, restarting polling.',
    );
    _startUsagePolling(user.uid);
  }

  void _listenToRTDBUsage(String uid) async {
    await _checkAndPerformRollovers(uid);
    _startUsagePolling(uid);
  }

  void _startUsagePolling(String uid) {
    _usagePollTimer?.cancel();

    debugPrint(
      '[Subscription] Starting usage polling for $uid every $pollIntervalSeconds seconds.',
    );

    // Initial fetch
    _fetchUsageData(uid);

    // Periodic fetch
    _usagePollTimer = Timer.periodic(
      Duration(seconds: pollIntervalSeconds),
      (_) => _fetchUsageData(uid),
    );
  }

  Future<void> _fetchUsageData(String uid) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();

      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // 1. Fetch daily usage
      final dailyUrl = Uri.parse(
        '$_rtdbBaseUrl/users/$uid/daily_usage/$todayStr/tokens.json?auth=$idToken',
      );
      final dailyResp = await _httpClient.get(dailyUrl);
      final dailyUsed = (jsonDecode(dailyResp.body) as num?)?.toInt() ?? 0;

      // 2. Fetch totals
      final totalsUrl = Uri.parse(
        '$_rtdbBaseUrl/users/$uid/usage/totals.json?auth=$idToken',
      );
      final totalsResp = await _httpClient.get(totalsUrl);
      final totalsData =
          jsonDecode(totalsResp.body) as Map<String, dynamic>? ?? {};

      final lifetimeUsed = (totalsData['lifetime'] as num?)?.toInt() ?? 0;
      final calendarUsed =
          (totalsData['calendar_monthly'] as num?)?.toInt() ?? 0;
      final subUsed =
          (totalsData['subscription_monthly'] as num?)?.toInt() ?? 0;
      final weeklyUsed = (totalsData['weekly'] as num?)?.toInt() ?? 0;

      _updateCurrentStatus(
        dailyTokensUsed: dailyUsed,
        weeklyTokensUsed: weeklyUsed,
        monthlyTokensUsed: subUsed > 0 ? subUsed : calendarUsed,
        lifetimeTokensUsed: lifetimeUsed,
      );
    } catch (e) {
      debugPrint('[Subscription] Error fetching usage via REST: $e');
    }
  }

  Future<void> _checkAndPerformRollovers(String uid) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();

      final url = Uri.parse(
        '$_rtdbBaseUrl/users/$uid/usage/totals.json?auth=$idToken',
      );
      final resp = await _httpClient.get(url);
      if (resp.statusCode != 200) return;
      final totals = jsonDecode(resp.body) as Map<String, dynamic>? ?? {};

      final now = DateTime.now();

      // --- 1. Calendar Rollover ---
      final currentMonthStr =
          '${now.year}_${now.month.toString().padLeft(2, '0')}';
      final lastCalendarMonth =
          totals['last_calendar_month'] as String? ?? currentMonthStr;

      if (currentMonthStr != lastCalendarMonth) {
        final calendarUsed = (totals['calendar_monthly'] as num?)?.toInt() ?? 0;
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('usage_history')
            .doc('calendar_$lastCalendarMonth')
            .set({
              'tokens': calendarUsed,
              'period_type': 'calendar',
              'period': lastCalendarMonth,
              'archivedAt': FieldValue.serverTimestamp(),
            });
        await _httpClient.patch(
          Uri.parse('$_rtdbBaseUrl/users/$uid/usage/totals.json?auth=$idToken'),
          body: jsonEncode({
            'calendar_monthly': 0,
            'last_calendar_month': currentMonthStr,
          }),
        );
        debugPrint(
          '[Subscription] Calendar rollover performed: $lastCalendarMonth',
        );
      }

      // --- 1.5 Weekly Rollover ---
      final currentMonday = now.subtract(Duration(days: now.weekday - 1));
      final currentWeekStr =
          '${currentMonday.year}_${currentMonday.month.toString().padLeft(2, '0')}_${currentMonday.day.toString().padLeft(2, '0')}';
      final lastWeekStr = totals['last_week'] as String? ?? currentWeekStr;

      if (currentWeekStr != lastWeekStr) {
        final weeklyUsed = (totals['weekly'] as num?)?.toInt() ?? 0;
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('usage_history')
            .doc('weekly_$lastWeekStr')
            .set({
              'tokens': weeklyUsed,
              'period_type': 'weekly',
              'period': lastWeekStr,
              'archivedAt': FieldValue.serverTimestamp(),
            });
        await _httpClient.patch(
          Uri.parse('$_rtdbBaseUrl/users/$uid/usage/totals.json?auth=$idToken'),
          body: jsonEncode({'weekly': 0, 'last_week': currentWeekStr}),
        );
        debugPrint('[Subscription] Weekly rollover performed: $lastWeekStr');
      }

      // --- 2. Subscription Rollover (Paid only) ---
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return;
      final userData = userDoc.data()!;
      final tier = userData['tier'] as String? ?? defaultTier;

      if (tier != defaultTier) {
        DateTime monthlyResetAt =
            (userData['monthlyResetAt'] as Timestamp?)?.toDate() ??
            now.add(const Duration(days: 30));

        if (now.isAfter(monthlyResetAt)) {
          final subUsed =
              (totals['subscription_monthly'] as num?)?.toInt() ?? 0;
          final cycleLabel =
              '${monthlyResetAt.subtract(const Duration(days: 30)).toIso8601String().split('T')[0]}__${monthlyResetAt.toIso8601String().split('T')[0]}';

          await _firestore
              .collection('users')
              .doc(uid)
              .collection('usage_history')
              .doc('subscription_$cycleLabel')
              .set({
                'tokens': subUsed,
                'period_type': 'subscription',
                'period': cycleLabel,
                'archivedAt': FieldValue.serverTimestamp(),
              });

          while (now.isAfter(monthlyResetAt)) {
            monthlyResetAt = monthlyResetAt.add(const Duration(days: 30));
          }

          await Future.wait([
            _httpClient.patch(
              Uri.parse(
                '$_rtdbBaseUrl/users/$uid/usage/totals.json?auth=$idToken',
              ),
              body: jsonEncode({'subscription_monthly': 0}),
            ),
            _firestore.collection('users').doc(uid).update({
              'monthlyResetAt': Timestamp.fromDate(monthlyResetAt),
            }),
          ]);
          debugPrint(
            '[Subscription] Subscription rollover performed for period ending $cycleLabel',
          );
        }
      }
    } catch (e) {
      debugPrint('[Subscription] Rollover check failed: $e');
    }
  }

  void _updateCurrentStatus({
    int? dailyTokensUsed,
    int? weeklyTokensUsed,
    int? monthlyTokensUsed,
    int? lifetimeTokensUsed,
    String? tier,
    DateTime? resetAt,
  }) {
    if (_currentStatus == null && tier == null) return;

    final wasExceeded = _currentStatus?.isExceeded ?? false;
    final newTier = tier ?? _currentStatus?.tier ?? defaultTier;
    final newDailyUsed =
        dailyTokensUsed ?? _currentStatus?.dailyTokensUsed ?? 0;
    final newWeeklyUsed =
        weeklyTokensUsed ?? _currentStatus?.weeklyTokensUsed ?? 0;
    final newMonthlyUsed =
        monthlyTokensUsed ?? _currentStatus?.monthlyTokensUsed ?? 0;
    final newLifetimeUsed =
        lifetimeTokensUsed ?? _currentStatus?.lifetimeTokensUsed ?? 0;
    final newReset =
        resetAt ?? _currentStatus?.dailyResetAt ?? _getNextDailyReset();

    _currentStatus = SubscriptionStatus(
      tier: newTier,
      dailyTokensUsed: newDailyUsed,
      weeklyTokensUsed: newWeeklyUsed,
      monthlyTokensUsed: newMonthlyUsed,
      lifetimeTokensUsed: newLifetimeUsed,
      dailyLimit: _getLimitForTier(newTier),
      dailyResetAt: newReset,
      periodLimit: _getPeriodLimitForTier(newTier),
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
    _userSub = _firestore.collection('users').doc(uid).snapshots().listen((
      doc,
    ) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!doc.exists) {
          _initializeUserDoc(uid);
          return;
        }

        final data = doc.data()!;
        final tierStr = data['tier'] as String? ?? defaultTier;
        final tier = tierStr;
        final resetAt =
            (data['dailyResetAt'] as Timestamp?)?.toDate() ??
            _getNextDailyReset();

        if (DateTime.now().isAfter(resetAt)) {
          _resetDailyQuota(uid);
          return;
        }

        final monthlyResetAt = (data['monthlyResetAt'] as Timestamp?)?.toDate();
        if (monthlyResetAt != null && DateTime.now().isAfter(monthlyResetAt)) {
          _resetMonthlyQuota(uid);
          return;
        }

        // Auto-expire trial
        if (tier == 'trial') {
          _checkTrialExpiry(uid, data);
        }

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

  Future<void> _resetMonthlyQuota(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'monthlyTokensUsed': 0,
      'monthlyResetAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
    });
    debugPrint('[Subscription] Monthly quota reset for $uid');
  }

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

  Future<void> _logQuotaExceeded(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastQuotaExceededAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[Subscription] Quota exceeded event logged.');
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

  /// Checks whether the current user has already used their one-time trial.
  Future<bool> hasUsedTrial() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return true; // no user = can't trial
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['trial_used'] as bool? ?? false;
  }

  /// Activates the trial for the current user. Returns an error message on
  /// failure, or null on success. The trial auto-expires after
  /// [trialDurationHours] by setting `trialExpiresAt` on the user doc.
  Future<String?> activateTrial() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'Not signed in';

    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.data()?['trial_used'] == true) {
      return 'Trial already used on this account';
    }

    // Get trial duration from config
    final trialConfig = _tierConfig('trial');
    final hours = (trialConfig?['trial_duration_hours'] as num?)?.toInt() ?? 24;
    final expiresAt = DateTime.now().add(Duration(hours: hours));

    await _firestore.collection('users').doc(uid).update({
      'tier': 'trial',
      'trial_used': true,
      'trialExpiresAt': Timestamp.fromDate(expiresAt),
      'trialActivatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint(
      '[Subscription] Trial activated for $uid, expires at $expiresAt',
    );
    return null; // success
  }

  /// Checks if the current trial has expired and downgrades to free tier.
  /// Called from [_listenToUserDoc] when tier is 'trial'.
  Future<void> _checkTrialExpiry(String uid, Map<String, dynamic> data) async {
    final expiresAt = (data['trialExpiresAt'] as Timestamp?)?.toDate();
    if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
      await _firestore.collection('users').doc(uid).update({
        'tier': defaultTier.isEmpty ? 'free' : defaultTier,
      });
      debugPrint('[Subscription] Trial expired for $uid, downgraded to free');
    }
  }

  Future<void> setTierDebug(String tier) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await setTierForOtherUser(uid, tier);
  }

  Future<void> setTierForOtherUser(String uid, String tier) async {
    await _firestore.collection('users').doc(uid).update({'tier': tier});
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

  String get defaultTier {
    final order = _monetizationConfig?['order'] as List<dynamic>? ?? [];
    return order.isNotEmpty ? order.first.toString() : '';
  }

  bool isHighestTier(String tier) {
    final order = _monetizationConfig?['order'] as List<dynamic>? ?? [];
    if (order.isEmpty) return false;
    return order.last.toString() == tier;
  }

  String getTierAt(int index) {
    final order = _monetizationConfig?['order'] as List<dynamic>? ?? [];
    if (order.isEmpty) return '';
    if (index < 0) return order.first.toString();
    if (index >= order.length) return order.last.toString();
    return order[index].toString();
  }

  String getNameForRank(int rank) {
    return getNameForTier(getTierAt(rank));
  }

  int getTierRank(String tier) {
    if (tier == defaultTier) return 0;
    final order = _monetizationConfig?['order'] as List<dynamic>? ?? [];
    final idx = order.indexOf(tier);
    return idx >= 0 ? idx : 0;
  }

  bool tierHasAccess(String currentTier, String requiredTier) {
    return getTierRank(currentTier) >= getTierRank(requiredTier);
  }

  int _getLimitForTier(String tier) {
    final config = _tierConfig(tier);
    if (config != null) {
      return (config['quotas']?['daily_tokens'] as num?)?.toInt() ?? 10000;
    }
    // Fallback: legacy flat structure or hardcoded defaults
    final limits = _monetizationConfig?['limits'] as Map<String, dynamic>?;
    if (limits != null) return (limits[tier] as num?)?.toInt() ?? 0;
    return tier == defaultTier ? 10000 : -1;
  }

  int _getPeriodLimitForTier(String tier) {
    final config = _tierConfig(tier);
    if (config != null) {
      return (config['quotas']?['period_tokens'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  String getPriceForTier(String tier) {
    final config = _tierConfig(tier);
    if (config != null) return config['price'] as String? ?? '';
    final prices = _monetizationConfig?['prices'] as Map<String, dynamic>?;
    return prices?[tier] ?? '';
  }

  String getRequirement(String category, String key, String fallback) {
    final requirements =
        _monetizationConfig?['requirements'] as Map<String, dynamic>?;
    if (requirements == null || !requirements.containsKey(category)) {
      return fallback;
    }
    final categoryMap = requirements[category] as Map<String, dynamic>;
    if (!categoryMap.containsKey(key)) return fallback;
    return categoryMap[key] as String;
  }

  String getNameForTier(String tier) {
    if (tier == defaultTier && defaultTier.isEmpty) return 'Free';
    final config = _tierConfig(tier);
    if (config != null) return config['name'] as String? ?? tier.toUpperCase();
    // Fallback: legacy flat structure
    final names = _monetizationConfig?['names'] as Map<String, dynamic>?;
    return names?[tier] ?? tier.toUpperCase();
  }

  SubscriptionStatus _getDefaultStatus() {
    return SubscriptionStatus(
      tier: defaultTier,
      dailyTokensUsed: 0,
      weeklyTokensUsed: 0,
      monthlyTokensUsed: 0,
      lifetimeTokensUsed: 0,
      dailyLimit: _getLimitForTier(defaultTier),
      dailyResetAt: _getNextDailyReset(),
    );
  }

  List<SubscriptionPlan> get availablePlans {
    if (_monetizationConfig == null) {
      debugPrint('[Subscription] availablePlans: _monetizationConfig is NULL');
      return [];
    }

    final order = _monetizationConfig?['order'] as List<dynamic>? ?? [];
    if (order.isEmpty) {
      debugPrint(
        '[Subscription] availablePlans: order is EMPTY. '
        'Config keys: ${_monetizationConfig?.keys.toList()}',
      );
      return [];
    }

    final tiers = _monetizationConfig?['tiers'] as Map<String, dynamic>?;
    final popular = _monetizationConfig?['popular'] as String? ?? '';

    // Prefer tiers structure if available
    if (tiers != null) {
      return order.map((key) {
        final id = key.toString();
        final config = tiers[id] as Map<String, dynamic>? ?? {};
        final quotas = config['quotas'] as Map<String, dynamic>? ?? {};
        return SubscriptionPlan(
          id: id,
          name: config['name']?.toString() ?? id.toUpperCase(),
          price: config['price']?.toString() ?? '',
          description: config['description']?.toString() ?? '',
          features:
              (config['display_features'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          isPopular: id == popular,
          isTrial: config['is_trial'] as bool? ?? false,
          trialDurationHours:
              (config['trial_duration_hours'] as num?)?.toInt() ?? 24,
          dailyTokens: (quotas['daily_tokens'] as num?)?.toInt() ?? 0,
          monthlyTokens: (quotas['monthly_tokens'] as num?)?.toInt() ?? 0,
          allowedTranslationModels:
              (config['allowed_translation_models'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          allowedTranscriptionModels:
              (config['allowed_transcription_models'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          requestsPerMinute:
              (config['rate_limits']?['requests_per_minute'] as num?)
                  ?.toInt() ??
              0,
          concurrentSessions:
              (config['rate_limits']?['concurrent_sessions'] as num?)
                  ?.toInt() ??
              1,
          engineLimits:
              (config['engine_limits'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, (v as num).toInt()),
              ) ??
              {},
        );
      }).toList();
    }

    return [];
  }

  void dispose() {
    _monetizationSub?.cancel();
    _userSub?.cancel();
    _usagePollTimer?.cancel();
    _statusController.close();
    _httpClient.close();
  }
}
