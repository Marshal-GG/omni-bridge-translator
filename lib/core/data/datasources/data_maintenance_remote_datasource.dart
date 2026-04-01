import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:omni_bridge/core/constants/firebase_paths.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';
import 'package:omni_bridge/core/network/rtdb_client.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';

abstract class IDataMaintenanceRemoteDataSource {
  Future<void> cleanupOldCaptions();
  Future<void> cleanupOldDailyUsage();
  Future<void> cleanupOldSessions();
}

class DataMaintenanceRemoteDataSource
    implements IDataMaintenanceRemoteDataSource {
  DataMaintenanceRemoteDataSource._();
  static final DataMaintenanceRemoteDataSource instance =
      DataMaintenanceRemoteDataSource._();

  static const String _tag = 'DataMaintenanceRemoteDataSource';

  FirebaseApp get _app => Firebase.app(RTDBClient.appName);
  FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(app: _app);

  final RTDBClient _rtdbClient = RTDBClient.instance;

  @override
  Future<void> cleanupOldCaptions() async {
    final userUid = _rtdbClient.uid;
    if (userUid == null) return;

    try {
      final retentionDays =
          SubscriptionRemoteDataSource.instance.captionRetentionDays;
      if (retentionDays <= 0) return; // free tier — nothing stored to clean

      final cutoffMs = DateTime.now()
          .subtract(Duration(days: retentionDays))
          .millisecondsSinceEpoch;

      final url = await _rtdbClient.getRTDBUrl(FirebasePaths.captions);
      if (url == null) return;

      final response = await _rtdbClient.request(
        (client) => client.get(url),
        context: 'cleanupOldCaptions:fetch',
        maxRetries: 1,
      );
      if (response == null || response.statusCode != 200) return;

      final raw = jsonDecode(response.body);
      if (raw == null || raw is! Map) return;
      final data = raw as Map<String, dynamic>;

      final Map<String, dynamic> deletions = {};
      for (final entry in data.entries) {
        final ts = (entry.value as Map<String, dynamic>?)?['timestamp'];
        if (ts is num && ts < cutoffMs) {
          deletions[entry.key] = null; // null = delete in RTDB
        }
      }

      if (deletions.isEmpty) return;

      final user = FirebaseAuth.instanceFor(app: _app).currentUser;
      if (user == null) return;
      final deleteUrl = await _rtdbClient.getAbsoluteUrl(
        FirebasePaths.userCaptions(userUid),
      );

      if (deleteUrl != null) {
        await _rtdbClient.request(
          (client) => client.patch(deleteUrl, body: jsonEncode(deletions)),
          context: 'cleanupOldCaptions:delete',
          maxRetries: 1,
        );
        AppLogger.i(
          'Cleaned up ${deletions.length} old captions (>${retentionDays}d).',
          tag: _tag,
        );
      }
    } catch (e) {
      AppLogger.e('Caption cleanup failed', tag: _tag, error: e);
    }
  }

  @override
  Future<void> cleanupOldDailyUsage() async {
    final userUid = _rtdbClient.uid;
    if (userUid == null) return;

    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 90));

      final url = await _rtdbClient.getAbsoluteUrl(
        FirebasePaths.userDailyUsage(userUid),
      );
      if (url == null) return;

      final shallowUrl = Uri.parse('${url.toString()}&shallow=true');
      final response = await _rtdbClient.request(
        (client) => client.get(shallowUrl),
        context: 'cleanupOldDailyUsage:fetch',
        maxRetries: 1,
      );
      if (response == null || response.statusCode != 200) return;

      final raw = jsonDecode(response.body);
      if (raw == null || raw is! Map) return;

      final Map<String, dynamic> deletions = {};
      for (final key in raw.keys) {
        try {
          final date = DateTime.parse(key.toString());
          if (date.isBefore(cutoffDate)) {
            deletions[key.toString()] = null;
          }
        } catch (_) {
          // invalid date key, ignore
        }
      }

      if (deletions.isEmpty) return;

      await _rtdbClient.request(
        (client) => client.patch(url, body: jsonEncode(deletions)),
        context: 'cleanupOldDailyUsage:delete',
        maxRetries: 1,
      );
      AppLogger.i(
        'Cleaned up ${deletions.length} old daily_usage entries (>=90d).',
        tag: _tag,
      );
    } catch (e) {
      AppLogger.e('Daily usage cleanup failed', tag: _tag, error: e);
    }
  }

  @override
  Future<void> cleanupOldSessions() async {
    final userUid = _rtdbClient.uid;
    if (userUid == null) return;
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
      final snapshots = await _firestore
          .collection(FirebasePaths.users)
          .doc(userUid)
          .collection(FirebasePaths.sessions)
          .where('startTime', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      if (snapshots.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      AppLogger.i(
        'Cleaned up ${snapshots.docs.length} old sessions from Firestore.',
        tag: _tag,
      );
    } catch (e) {
      AppLogger.e('Session cleanup failed', tag: _tag, error: e);
    }
  }
}
