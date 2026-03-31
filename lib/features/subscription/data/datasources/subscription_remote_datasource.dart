import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import 'package:omni_bridge/features/subscription/domain/entities/subscription_plan.dart';
import 'package:omni_bridge/core/network/rtdb_client.dart';
import 'package:omni_bridge/core/constants/firebase_paths.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';
import 'package:omni_bridge/core/data/interfaces/resettable.dart';

class SubscriptionRemoteDataSource implements IResettable {
  SubscriptionRemoteDataSource._();
  static final SubscriptionRemoteDataSource instance =
      SubscriptionRemoteDataSource._();

  static const String _tag = 'SubscriptionRemoteDataSource';

  FirebaseApp get _app => Firebase.app(RTDBClient.appName);
  FirebaseAuth get _auth => FirebaseAuth.instanceFor(app: _app);
  FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(app: _app);

  // --- Dynamic Monetization Config ---
  Map<String, dynamic>? _monetizationConfig;
  StreamSubscription? _monetizationSub;

  /// Notifies listeners whenever the monetization config changes (plans become available).
  final configNotifier = ValueNotifier<int>(0);

  final http.Client _httpClient = http.Client();

  final _statusController = StreamController<QuotaStatus>.broadcast();
  Stream<QuotaStatus> get statusStream => _statusController.stream;

  QuotaStatus? _currentStatus;
  QuotaStatus? get currentStatus => _currentStatus;

  // Tracks current tier to detect upgrade/downgrade events
  String? _lastKnownTier;

  StreamSubscription? _authSub;
  StreamSubscription? _userSub;

  // Track the notified engines for the current session to avoid spamming the user
  final Set<String> _notifiedEngines = {};
  final activeEngineFallbacks = ValueNotifier<Set<String>>({});

  void init() {
    _listenToMonetizationConfig();
    _listenToAuthState();
  }

  void dispose() {
    _monetizationSub?.cancel();
    _authSub?.cancel();
    _userSub?.cancel();
    _statusController.close();
    _httpClient.close();
  }

  void _listenToAuthState() {
    _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _lastKnownTier = null;
        _listenToUserDoc(user.uid);
      } else {
        reset();
      }
    });
  }

  /// Resets the singleton state. Called on logout to prevent state leakage.
  @override
  void reset() {
    _userSub?.cancel();
    _userSub = null;
    _lastKnownTier = null;
    _currentStatus = null;
    
    _notifiedEngines.clear();
    activeEngineFallbacks.value = {};
    
    // Also cancel monetization sub to be safe, though it's system-wide
    // _monetizationSub?.cancel(); 
    
    _statusController.add(_getDefaultStatus());
    AppLogger.d('State reset', tag: _tag);
  }

  void _listenToMonetizationConfig() {
    _monetizationSub?.cancel();
    _monetizationSub = _firestore
        .collection(FirebasePaths.system)
        .doc(FirebasePaths.monetization)
        .snapshots()
        .listen((doc) {
          if (doc.exists) {
            _monetizationConfig = doc.data();
            AppLogger.d(
              'Monetization config updated. Keys: ${_monetizationConfig?.keys.toList()} - Interval: $pollIntervalSeconds',
              tag: _tag,
            );
            // Always emit status so bloc/UI refreshes with the latest plans
            if (_currentStatus != null) {
              _updateCurrentStatus();
            } else {
              _statusController.add(_getDefaultStatus());
            }
            // Notify any ValueListenableBuilder widgets (e.g. admin panel)
            configNotifier.value++;
          } else {
            AppLogger.w('${FirebasePaths.system}/${FirebasePaths.monetization} document does NOT exist', tag: _tag);
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

  /// Returns the configured type ('asr' or 'translation') for an engine ID.
  /// Reads from system/monetization → model_overrides → {id} → type.
  /// Returns `null` if config is not loaded or the engine has no entry.
  String? getModelType(String engineId) {
    final overrides =
        _monetizationConfig?['model_overrides'] as Map<String, dynamic>?;
    final entry = overrides?[engineId] as Map<String, dynamic>?;
    return entry?['type'] as String?;
  }

  /// Returns a set of all engine IDs explicitly configured in model_overrides.
  Set<String> getConfiguredEngines() {
    final overrides =
        _monetizationConfig?['model_overrides'] as Map<String, dynamic>?;
    return overrides?.keys.toSet() ?? {};
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

  void _updateCurrentStatus({
    String? tier,
    DateTime? resetAt,
  }) {
    if (_currentStatus == null && tier == null) return;

    final newTier = tier ?? _currentStatus?.tier ?? defaultTier;
    final newReset =
        resetAt ?? _currentStatus?.dailyResetAt ?? _getNextDailyReset();

    _currentStatus = QuotaStatus(
      tier: newTier,
      dailyTokensUsed: _currentStatus?.dailyTokensUsed ?? 0,
      weeklyTokensUsed: _currentStatus?.weeklyTokensUsed ?? 0,
      monthlyTokensUsed: _currentStatus?.monthlyTokensUsed ?? 0,
      lifetimeTokensUsed: _currentStatus?.lifetimeTokensUsed ?? 0,
      dailyLimit: getLimitForTier(newTier),
      dailyResetAt: newReset,
    );
    _statusController.add(_currentStatus!);
  }

  void _listenToUserDoc(String uid) {
    _userSub?.cancel();
    _userSub = _firestore.collection(FirebasePaths.users).doc(uid).snapshots().listen((
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
    await _firestore.collection(FirebasePaths.users).doc(uid).set({
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
    await _firestore.collection(FirebasePaths.users).doc(uid).update({
      'dailyResetAt': Timestamp.fromDate(_getNextDailyReset()),
    });
  }

  Future<void> _resetMonthlyQuota(String uid) async {
    await _firestore.collection(FirebasePaths.users).doc(uid).update({
      'monthlyTokensUsed': 0,
      'monthlyResetAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
    });
    AppLogger.i('Monthly quota reset for $uid', tag: _tag);
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
          .collection(FirebasePaths.users)
          .doc(uid)
          .collection(FirebasePaths.subscriptionEvents)
          .add({
            'event': event,
            'from': fromTier,
            'to': toTier,
            'timestamp': FieldValue.serverTimestamp(),
            'via': 'razorpay',
          });

      if (fromTier == defaultTier && isUpgrade) {
        await _firestore.collection(FirebasePaths.users).doc(uid).update({
          'subscriptionSince': FieldValue.serverTimestamp(),
          'paymentProvider': 'razorpay',
          'monthlyTokensUsed': 0,
          'monthlyResetAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30)),
          ),
        });
      }

      AppLogger.i('Event logged: $event ($fromTier → $toTier)', tag: _tag);
    } catch (e) {
      AppLogger.e('Failed to log subscription event', tag: _tag, error: e);
    }
  }

  Future<void> openCheckout(String tierId) async {
    final config =
        _monetizationConfig?['payment_links'] as Map<String, dynamic>?;
    final String? url = config?[tierId] as String?;

    if (url != null && await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      AppLogger.w('No payment link found for tier: $tierId', tag: _tag);
    }
  }

  /// Checks whether the current user has already used their one-time trial.
  Future<bool> hasUsedTrial() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return true; // no user = can't trial
    final doc = await _firestore.collection(FirebasePaths.users).doc(uid).get();
    return doc.data()?['trial_used'] as bool? ?? false;
  }

  /// Activates the trial for the current user. Returns an error message on
  /// failure, or null on success. The trial auto-expires after
  /// [trialDurationHours] by setting `trialExpiresAt` on the user doc.
  Future<String?> activateTrial() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'Not signed in';

    final doc = await _firestore.collection(FirebasePaths.users).doc(uid).get();
    if (doc.data()?['trial_used'] == true) {
      return 'Trial already used on this account';
    }

    // Get trial duration from config
    final trialConfig = _tierConfig('trial');
    final hours = (trialConfig?['trial_duration_hours'] as num?)?.toInt() ?? 24;
    final expiresAt = DateTime.now().add(Duration(hours: hours));

    await _firestore.collection(FirebasePaths.users).doc(uid).update({
      'tier': 'trial',
      'trial_used': true,
      'trialExpiresAt': Timestamp.fromDate(expiresAt),
      'trialActivatedAt': FieldValue.serverTimestamp(),
    });

    AppLogger.i('Trial activated for $uid, expires at $expiresAt', tag: _tag);
    return null; // success
  }

  /// Checks if the current trial has expired and downgrades to free tier.
  /// Called from [_listenToUserDoc] when tier is 'trial'.
  Future<void> _checkTrialExpiry(String uid, Map<String, dynamic> data) async {
    final expiresAt = (data['trialExpiresAt'] as Timestamp?)?.toDate();
    if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
      await _firestore.collection(FirebasePaths.users).doc(uid).update({
        'tier': defaultTier.isEmpty ? 'free' : defaultTier,
      });
      AppLogger.i('Trial expired for $uid, downgraded to free', tag: _tag);
    }
  }

  Future<void> setTierDebug(String tier) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await setTierForOtherUser(uid, tier);
  }

  Future<void> setTierForOtherUser(String uid, String tier) async {
    await _firestore.collection(FirebasePaths.users).doc(uid).update({'tier': tier});
    AppLogger.i('Tier for $uid set to $tier', tag: _tag);
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

  int getLimitForTier(String tier) {
    final config = _tierConfig(tier);
    if (config != null) {
      return (config['quotas']?['daily_tokens'] as num?)?.toInt() ?? 10000;
    }
    // Fallback: legacy flat structure or hardcoded defaults
    final limits = _monetizationConfig?['limits'] as Map<String, dynamic>?;
    if (limits != null) return (limits[tier] as num?)?.toInt() ?? 0;
    return tier == defaultTier ? 10000 : -1;
  }

  int getPeriodLimitForTier(String tier) {
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

  QuotaStatus _getDefaultStatus() {
    return QuotaStatus(
      tier: defaultTier,
      dailyTokensUsed: 0,
      weeklyTokensUsed: 0,
      monthlyTokensUsed: 0,
      lifetimeTokensUsed: 0,
      dailyLimit: 10000,
      dailyResetAt: _getNextDailyReset(),
    );
  }

  List<SubscriptionPlan> get availablePlans {
    if (_monetizationConfig == null) {
      AppLogger.w('availablePlans: _monetizationConfig is NULL', tag: _tag);
      return [];
    }

    final order = _monetizationConfig?['order'] as List<dynamic>? ?? [];
    if (order.isEmpty) {
      AppLogger.w(
        'availablePlans: order is EMPTY. Config keys: ${_monetizationConfig?.keys.toList()}',
        tag: _tag,
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

  bool shouldShowEngineLimitNotice(String engineId) {
    if (_notifiedEngines.contains(engineId)) return false;
    _notifiedEngines.add(engineId);
    activeEngineFallbacks.value = {...activeEngineFallbacks.value, engineId};
    return true;
  }

  void clearEngineLimitNotices() {
    _notifiedEngines.clear();
    activeEngineFallbacks.value = {};
  }
}
