import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:omni_bridge/core/network/rtdb_client.dart';
import 'package:omni_bridge/core/constants/firebase_paths.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import 'package:omni_bridge/features/usage/data/models/quota_status_dto.dart';
import 'package:omni_bridge/core/data/interfaces/resettable.dart';

class UsageRemoteDataSource implements IResettable {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  UsageRemoteDataSource({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ??
            FirebaseAuth.instanceFor(
                app: Firebase.app(RTDBClient.appName)),
        _firestore = firestore ??
            FirebaseFirestore.instanceFor(
                app: Firebase.app(RTDBClient.appName));

  static final UsageRemoteDataSource instance = UsageRemoteDataSource();

  static const String _tag = 'UsageRemoteDataSource';

  String? get currentUid => _auth.currentUser?.uid;

  final _quotaStatusController = StreamController<QuotaStatus>.broadcast();
  Stream<QuotaStatus> get quotaStatusStream => _quotaStatusController.stream;

  QuotaStatus? _currentQuotaStatus;
  QuotaStatus? get currentQuotaStatus => _currentQuotaStatus;

  int Function()? _pollIntervalProvider;
  String Function()? _defaultTierProvider;
  int Function(String engineId, [String? tier])? _limitProvider;
  int Function(String tier)? _periodLimitProvider;

  Timer? _usagePollTimer;
  int? _currentPollInterval;

  final Map<String, int> _engineMonthlyUsages = {};
  Map<String, int> get engineMonthlyUsage => _engineMonthlyUsages;

  StreamSubscription? _authSub;
  StreamSubscription? _tierSub;

  /// Starts monitoring auth state and sets up polling.
  void init({
    required int Function() pollIntervalProvider,
    required String Function() defaultTierProvider,
    required int Function(String engineId, [String? tier]) limitProvider,
    required int Function(String tier) periodLimitProvider,
    required Stream<QuotaStatus> tierStream,
  }) {
    _pollIntervalProvider = pollIntervalProvider;
    _defaultTierProvider = defaultTierProvider;
    _limitProvider = limitProvider;
    _periodLimitProvider = periodLimitProvider;

    _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _listenToTierChanges(user.uid, tierStream: tierStream);
        _startUsagePolling(user.uid);
      } else {
        reset();
      }
    });
  }

  void dispose() {
    _authSub?.cancel();
    _tierSub?.cancel();
    _usagePollTimer?.cancel();
    _quotaStatusController.close();
  }

  @override
  void reset() {
    _usagePollTimer?.cancel();
    _usagePollTimer = null;
    _tierSub?.cancel();
    _tierSub = null;
    _currentQuotaStatus = null;
    _engineMonthlyUsages.clear();

    // Emit a default status to clear UI
    if (_defaultTierProvider != null) {
      _quotaStatusController.add(_getDefaultStatus(_defaultTierProvider!()));
    }
    AppLogger.d('State reset', tag: _tag);
  }

  void _listenToTierChanges(
    String uid, {
    required Stream<QuotaStatus> tierStream,
  }) {
    _tierSub?.cancel();
    _tierSub = tierStream.listen((subStatus) {
      _maybeRestartPolling(uid);
      _updateCurrentQuotaStatus(
        tier: subStatus.tier,
        dailyResetAt: subStatus.dailyResetAt,
        monthlyResetAt: subStatus.monthlyResetAt,
      );
    });
  }

  void _maybeRestartPolling(String uid) {
    if (_pollIntervalProvider == null) return;
    final newInterval = _pollIntervalProvider!();
    if (_currentPollInterval == newInterval) return;

    _currentPollInterval = newInterval;
    AppLogger.d('Poll interval changed to ${newInterval}s, restarting polling.', tag: _tag);
    _startUsagePolling(uid);
  }

  void _startUsagePolling(String uid) {
    _usagePollTimer?.cancel();
    if (_pollIntervalProvider == null) return;

    final interval = _pollIntervalProvider!();

    AppLogger.d('Starting usage polling for $uid every $interval seconds.', tag: _tag);

    // Initial fetch
    _fetchUsageData(uid);

    // Periodic fetch
    _usagePollTimer = Timer.periodic(
      Duration(seconds: interval),
      (_) => _fetchUsageData(uid),
    );
  }

  Future<void> _fetchUsageData(String uid) async {
    try {
      final user = _auth.currentUser;
      if (user == null ||
          _defaultTierProvider == null ||
          _limitProvider == null ||
          _periodLimitProvider == null) {
        return;
      }

      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // 1. Fetch daily usage
      final dailyUrl = await RTDBClient.instance.getRTDBUrl('${FirebasePaths.dailyUsage}/$todayStr/tokens');
      if (dailyUrl == null) return;
      final dailyResp = await http.get(dailyUrl);
      final dailyUsed = (jsonDecode(dailyResp.body) as num?)?.toInt() ?? 0;

      // 2. Fetch totals
      final totalsUrl = await RTDBClient.instance.getRTDBUrl(FirebasePaths.usageTotals);
      if (totalsUrl == null) return;
      final totalsResp = await http.get(totalsUrl);
      final totalsData =
          jsonDecode(totalsResp.body) as Map<String, dynamic>? ?? {};

      // 3. Fetch per-engine monthly totals
      _engineMonthlyUsages.clear();
      final modelsUrl = await RTDBClient.instance.getRTDBUrl('${FirebasePaths.usageTotals}/subscription_monthly_models');
      if (modelsUrl == null) return;
      final modelsResp = await http.get(modelsUrl);
      final modelsData =
          jsonDecode(modelsResp.body) as Map<String, dynamic>? ?? {};
      modelsData.forEach((engine, val) {
        if (val is Map<String, dynamic>) {
          _engineMonthlyUsages[engine] = (val['tokens'] as num?)?.toInt() ?? 0;
        } else if (val is num) {
          _engineMonthlyUsages[engine] = val.toInt();
        }
      });

      // 4. Update via DTO
      final currentTier = _currentQuotaStatus?.tier ?? _defaultTierProvider!();
      final quotaDto = QuotaStatusDto.fromJson(
        totalsData,
        tier: currentTier,
        dailyLimit: _limitProvider!(currentTier),
        periodLimit: _periodLimitProvider!(currentTier),
        dailyResetAt: _currentQuotaStatus?.dailyResetAt ?? DateTime.now(),
        monthlyResetAt: _currentQuotaStatus?.monthlyResetAt,
      );

      _updateCurrentQuotaStatus(
        dailyTokensUsed: dailyUsed,
        weeklyTokensUsed: quotaDto.weeklyTokensUsed,
        monthlyTokensUsed: quotaDto.monthlyTokensUsed,
        lifetimeTokensUsed: quotaDto.lifetimeTokensUsed,
        monthlyResetAt: quotaDto.monthlyResetAt,
      );
    } catch (e) {
      AppLogger.e('Error fetching usage via REST', tag: _tag, error: e);
    }
  }

  Future<Map<String, dynamic>> fetchUsageTotals(String uid) async {
    final url = await RTDBClient.instance.getRTDBUrl(FirebasePaths.usageTotals);
    if (url == null) return {};
    final resp = await http.get(url);
    if (resp.statusCode != 200) return {};
    return jsonDecode(resp.body) as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> getModelUsageStatsRaw(String uid) async {
    final url = await RTDBClient.instance.getRTDBUrl(FirebasePaths.modelStats);
    if (url == null) return {};
    final response = await http.get(url);
    if (response.statusCode != 200) return {};
    return jsonDecode(response.body) as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> getDailyUsageHistoryRaw(String uid) async {
    final url = await RTDBClient.instance.getRTDBUrl(FirebasePaths.dailyUsage);
    if (url == null) return {};
    final response = await http.get(url);
    if (response.statusCode != 200) return {};
    return jsonDecode(response.body) as Map<String, dynamic>? ?? {};
  }

  Future<void> rolloverCalendar(
    String uid,
    String lastMonth,
    String currentMonth,
    int tokens,
  ) async {
    final url = await RTDBClient.instance.getRTDBUrl(FirebasePaths.usageTotals);
    if (url == null) return;

    await _firestore
        .collection(FirebasePaths.users)
        .doc(uid)
        .collection(FirebasePaths.usageHistory)
        .doc('calendar_$lastMonth')
        .set({
      'tokens': tokens,
      'period_type': 'calendar',
      'period': lastMonth,
      'archivedAt': FieldValue.serverTimestamp(),
    });

    await http.patch(
      url,
      body: jsonEncode({
        'calendar_monthly': 0,
        'last_calendar_month': currentMonth,
      }),
    );
    AppLogger.i('Calendar rollover performed: $lastMonth', tag: _tag);
  }

  Future<void> rolloverWeekly(
    String uid,
    String lastWeek,
    String currentWeek,
    int tokens,
  ) async {
    final url = await RTDBClient.instance.getRTDBUrl(FirebasePaths.usageTotals);
    if (url == null) return;

    await _firestore
        .collection(FirebasePaths.users)
        .doc(uid)
        .collection(FirebasePaths.usageHistory)
        .doc('weekly_$lastWeek')
        .set({
      'tokens': tokens,
      'period_type': 'weekly',
      'period': lastWeek,
      'archivedAt': FieldValue.serverTimestamp(),
    });

    await http.patch(
      url,
      body: jsonEncode({'weekly': 0, 'last_week': currentWeek}),
    );
    AppLogger.i('Weekly rollover performed: $lastWeek', tag: _tag);
  }

  Future<void> rolloverSubscription(
    String uid,
    String cycleLabel,
    int tokens,
    DateTime nextReset,
  ) async {
    final url = await RTDBClient.instance.getRTDBUrl(FirebasePaths.usageTotals);
    if (url == null) return;

    await _firestore
        .collection(FirebasePaths.users)
        .doc(uid)
        .collection(FirebasePaths.usageHistory)
        .doc('subscription_$cycleLabel')
        .set({
      'tokens': tokens,
      'period_type': 'subscription',
      'period': cycleLabel,
      'archivedAt': FieldValue.serverTimestamp(),
    });

    await Future.wait([
      http.patch(
        url,
        body: jsonEncode({
          'subscription_monthly': 0,
          'subscription_monthly_models': null,
        }),
      ),
      _firestore.collection(FirebasePaths.users).doc(uid).update({
        'monthlyResetAt': Timestamp.fromDate(nextReset),
      }),
    ]);
    AppLogger.i('Subscription rollover performed: $cycleLabel', tag: _tag);
  }

  void _updateCurrentQuotaStatus({
    int? dailyTokensUsed,
    int? weeklyTokensUsed,
    int? monthlyTokensUsed,
    int? lifetimeTokensUsed,
    String? tier,
    DateTime? dailyResetAt,
    DateTime? monthlyResetAt,
  }) {
    if (_defaultTierProvider == null ||
        _limitProvider == null ||
        _periodLimitProvider == null) {
      return;
    }

    final newTier = tier ?? _currentQuotaStatus?.tier ?? _defaultTierProvider!();
    final newDailyReset =
        dailyResetAt ?? _currentQuotaStatus?.dailyResetAt ?? DateTime.now();
    final newMonthlyReset =
        monthlyResetAt ?? _currentQuotaStatus?.monthlyResetAt;

    final newDailyUsed =
        dailyTokensUsed ?? _currentQuotaStatus?.dailyTokensUsed ?? 0;
    final newWeeklyUsed =
        weeklyTokensUsed ?? _currentQuotaStatus?.weeklyTokensUsed ?? 0;
    final newMonthlyUsed =
        monthlyTokensUsed ?? _currentQuotaStatus?.monthlyTokensUsed ?? 0;
    final newLifetimeUsed =
        lifetimeTokensUsed ?? _currentQuotaStatus?.lifetimeTokensUsed ?? 0;

    final wasExceeded = _currentQuotaStatus?.isExceeded ?? false;

    _currentQuotaStatus = QuotaStatus(
      tier: newTier,
      dailyTokensUsed: newDailyUsed,
      weeklyTokensUsed: newWeeklyUsed,
      monthlyTokensUsed: newMonthlyUsed,
      lifetimeTokensUsed: newLifetimeUsed,
      dailyLimit: _limitProvider!(newTier),
      periodLimit: _periodLimitProvider!(newTier),
      dailyResetAt: newDailyReset,
      monthlyResetAt: newMonthlyReset,
    );
    _quotaStatusController.add(_currentQuotaStatus!);

    if (!wasExceeded && _currentQuotaStatus!.isExceeded) {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        _logQuotaExceeded(uid);
      }
    }
  }

  Future<void> _logQuotaExceeded(String uid) async {
    try {
      await _firestore.collection(FirebasePaths.users).doc(uid).update({
        'lastQuotaExceededAt': FieldValue.serverTimestamp(),
      });
      AppLogger.i('Quota exceeded event logged.', tag: _tag);
    } catch (e) {
      AppLogger.e('Failed to log quota exceeded', tag: _tag, error: e);
    }
  }

  QuotaStatus _getDefaultStatus(String defaultTier) {
    return QuotaStatus(
      tier: defaultTier,
      dailyTokensUsed: 0,
      weeklyTokensUsed: 0,
      monthlyTokensUsed: 0,
      lifetimeTokensUsed: 0,
      dailyLimit: 10000,
      dailyResetAt: DateTime.now().add(const Duration(days: 1)),
    );
  }
}
