import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TranscriptionRemoteDataSource {
  TranscriptionRemoteDataSource._();
  static final TranscriptionRemoteDataSource instance = TranscriptionRemoteDataSource._();

  static final String _appName = kDebugMode
      ? 'OmniBridge-Debug'
      : 'OmniBridge-Release';
  FirebaseApp get _app => Firebase.app(_appName);
  FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(app: _app);

  Map<String, dynamic>? _config;
  Map<String, dynamic>? get config => _config;

  void init() {
    _listenToTranscriptionConfig();
  }

  void _listenToTranscriptionConfig() {
    _firestore
        .collection('system')
        .doc('transcription_config')
        .snapshots()
        .listen((doc) {
          if (doc.exists) {
            _config = doc.data();
          }
        });
  }
}
