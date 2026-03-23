
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:omni_bridge/core/data/datasources/usage_metrics_remote_datasource.dart';
import 'package:omni_bridge/features/settings/domain/entities/system_config.dart';

abstract class ISettingsRemoteDataSource {
  Future<Map<String, dynamic>> getSystemConfig();
  Future<dynamic> getGoogleCredentials();
  Future<void> syncSettings(Map<String, dynamic> settings);
  Future<Map<String, dynamic>?> getSettings();
  Future<void> logEvent(String name, {Map<String, dynamic>? parameters});
}

class SettingsRemoteDataSourceImpl implements ISettingsRemoteDataSource {
  static final String _appName = kDebugMode ? 'OmniBridge-Debug' : 'OmniBridge-Release';
  FirebaseApp get _app => Firebase.app(_appName);
  FirebaseAuth get _auth => FirebaseAuth.instanceFor(app: _app);
  FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(app: _app);

  String? get uid => _auth.currentUser?.uid;

  @override
  Future<Map<String, dynamic>> getSystemConfig() async {
    try {
      final doc = await _firestore
          .collection('system')
          .doc('translation_config')
          .get();
      final data = doc.data() ?? {};
      
      return data;
    } catch (e) {
      debugPrint('[Settings] Failed to fetch system config: $e');
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
      debugPrint('[Settings] Cannot sync settings: UID is null.');
      return;
    }
    try {
      debugPrint('[Settings] Attempting to sync settings for UID: $uid');
      
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('app_preferences')
          .set({
            ...settingsData,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      debugPrint('[Settings] User settings successfully synced to Firestore.');
    } catch (e) {
      debugPrint('[Settings] Critical error syncing user settings: $e');
      UsageMetricsRemoteDataSource.instance.logEvent('Failed to sync user settings', {'error': e.toString()});
    }
  }

  @override
  Future<Map<String, dynamic>?> getSettings() async {
    if (uid == null) {
      debugPrint('[Settings] Cannot fetch settings: UID is null.');
      return null;
    }
    try {
      debugPrint('[Settings] Fetching settings for UID: $uid');
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('app_preferences')
          .get();
      if (doc.exists) {
        debugPrint(
          '[Settings] Successfully fetched user settings from Firestore.',
        );
        return doc.data();
      } else {
        debugPrint('[Settings] No settings found in Firestore for UID: $uid');
      }
    } catch (e) {
      debugPrint('[Settings] Critical error fetching user settings: $e');
      UsageMetricsRemoteDataSource.instance.logEvent('Failed to fetch user settings', {'error': e.toString()});
    }
    return null;
  }

  @override
  Future<void> logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    return UsageMetricsRemoteDataSource.instance.logEvent(eventName, parameters);
  }
}
