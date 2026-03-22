import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:omni_bridge/features/subscription/data/datasources/tracking_remote_datasource.dart';
import 'package:omni_bridge/features/translation/data/datasources/transcription_remote_datasource.dart';

class StartupRemoteDataSource {
  StartupRemoteDataSource._();
  static final StartupRemoteDataSource instance = StartupRemoteDataSource._();

  static final String _appName = kDebugMode
      ? 'OmniBridge-Debug'
      : 'OmniBridge-Release';
  FirebaseApp get _app => Firebase.app(_appName);
  FirebaseAuth get _auth => FirebaseAuth.instanceFor(app: _app);

  Future<void> initializeServices() async {
    debugPrint('[Startup] Initializing remote services...');
    
    // Auth-independent services
    TranscriptionRemoteDataSource.instance.init();
    SubscriptionRemoteDataSource.instance.init();

    // Session tracking (requires auth)
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        TrackingRemoteDataSource.instance.startSession();
      } else {
        TrackingRemoteDataSource.instance.endSession();
      }
    });

    final info = await PackageInfo.fromPlatform();
    debugPrint('[Startup] App Version: ${info.version}+${info.buildNumber}');
  }
}
