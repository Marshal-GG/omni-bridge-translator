import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:omni_bridge/core/data/interfaces/resettable.dart';
import 'package:omni_bridge/core/network/rtdb_client.dart';
import 'package:omni_bridge/core/constants/firebase_paths.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';

class TranscriptionRemoteDataSource implements IResettable {
  TranscriptionRemoteDataSource._();
  static final TranscriptionRemoteDataSource instance =
      TranscriptionRemoteDataSource._();

  FirebaseApp get _app => Firebase.app(RTDBClient.appName);
  FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(app: _app);

  Map<String, dynamic>? _config;
  Map<String, dynamic>? get config => _config;

  StreamSubscription? _subscription;

  void init() {
    AppLogger.i(
      '[Transcription] Initializing config listener...',
      tag: 'Transcription',
    );
    _listenToTranscriptionConfig();
  }

  void _listenToTranscriptionConfig() {
    _subscription?.cancel();
    _subscription = _firestore
        .doc(FirebasePaths.transcriptionConfig)
        .snapshots()
        .listen(
          (doc) {
            if (doc.exists) {
              _config = doc.data();
              AppLogger.d(
                '[Transcription] Config updated: $_config',
                tag: 'Transcription',
              );
            }
          },
          onError: (e) {
            AppLogger.e(
              '[Transcription] Config error: $e',
              tag: 'Transcription',
              error: e,
            );
          },
        );
  }

  @override
  void reset() {
    _subscription?.cancel();
    _subscription = null;
    _config = null;
    AppLogger.i('[Transcription] Resource reset.', tag: 'Transcription');
  }
}
