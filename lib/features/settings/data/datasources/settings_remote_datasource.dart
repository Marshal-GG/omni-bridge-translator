import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:omni_bridge/core/network/rtdb_client.dart';
import 'package:omni_bridge/core/data/datasources/usage_metrics_remote_datasource.dart';
import 'package:omni_bridge/features/settings/domain/entities/system_config.dart';
import 'package:omni_bridge/core/constants/firebase_paths.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';
import 'package:omni_bridge/core/data/interfaces/resettable.dart';

abstract class ISettingsRemoteDataSource {
  Future<Map<String, dynamic>> getSystemConfig();
  Future<dynamic> getGoogleCredentials();
  Future<void> syncSettings(Map<String, dynamic> settings);
  Future<Map<String, dynamic>?> getSettings();
  Future<void> logEvent(String name, {Map<String, dynamic>? parameters});
}

class SettingsRemoteDataSourceImpl
    implements ISettingsRemoteDataSource, IResettable {
  FirebaseApp get _app => Firebase.app(RTDBClient.appName);
  FirebaseAuth get _auth => FirebaseAuth.instanceFor(app: _app);
  FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(app: _app);

  static const String _tag = 'SettingsRemoteDataSource';

  String? get uid => _auth.currentUser?.uid;

  @override
  void reset() {
    // No local state to reset yet, but satisfying the interface.
    AppLogger.d('Reset called', tag: _tag);
  }

  @override
  Future<Map<String, dynamic>> getSystemConfig() async {
    try {
      final doc = await _firestore
          .collection(FirebasePaths.system)
          .doc(FirebasePaths.translationConfig)
          .get();
      final data = doc.data() ?? {};

      return data;
    } catch (e) {
      AppLogger.e('Failed to fetch system config', tag: _tag, error: e);
      return {};
    }
  }

  @override
  Future<dynamic> getGoogleCredentials() async {
    final systemData = await getSystemConfig();
    final config = SystemConfig.fromMap(systemData);
    return config.googleCredentials;
  }

  @override
  Future<void> syncSettings(Map<String, dynamic> settingsData) async {
    if (uid == null) {
      AppLogger.w('Cannot sync settings: UID is null.', tag: _tag);
      return;
    }
    try {
      AppLogger.d('Attempting to sync settings for UID: $uid', tag: _tag);

      await _firestore
          .collection(FirebasePaths.users)
          .doc(uid)
          .collection(FirebasePaths.settings)
          .doc(FirebasePaths.appPreferences)
          .set({
            ...settingsData,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      AppLogger.i('User settings successfully synced to Firestore.', tag: _tag);
    } catch (e) {
      AppLogger.e('Critical error syncing user settings', tag: _tag, error: e);
      UsageMetricsRemoteDataSource.instance.logEvent(
        'Failed to sync user settings',
        {'error': e.toString()},
      );
    }
  }

  @override
  Future<Map<String, dynamic>?> getSettings() async {
    if (uid == null) {
      AppLogger.w('Cannot fetch settings: UID is null.', tag: _tag);
      return null;
    }
    try {
      AppLogger.d('Fetching settings for UID: $uid', tag: _tag);
      final doc = await _firestore
          .collection(FirebasePaths.users)
          .doc(uid)
          .collection(FirebasePaths.settings)
          .doc(FirebasePaths.appPreferences)
          .get();
      if (doc.exists) {
        AppLogger.i(
          'Successfully fetched user settings from Firestore.',
          tag: _tag,
        );
        return doc.data();
      } else {
        AppLogger.i('No settings found in Firestore for UID: $uid', tag: _tag);
      }
    } catch (e) {
      AppLogger.e('Critical error fetching user settings', tag: _tag, error: e);
      UsageMetricsRemoteDataSource.instance.logEvent(
        'Failed to fetch user settings',
        {'error': e.toString()},
      );
    }
    return null;
  }

  @override
  Future<void> logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    return UsageMetricsRemoteDataSource.instance.logEvent(
      eventName,
      parameters,
    );
  }
}
