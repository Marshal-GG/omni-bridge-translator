import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:omni_bridge/core/constants/firebase_paths.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';
import 'package:omni_bridge/core/network/rtdb_client.dart';
import 'package:omni_bridge/core/data/interfaces/resettable.dart';
import '../../domain/entities/update_info.dart';

class UpdateRemoteDataSource implements IResettable {
  final FirebaseFirestore _firestore;

  UpdateRemoteDataSource({FirebaseFirestore? firestore})
    : _firestore =
          firestore ??
          FirebaseFirestore.instanceFor(app: Firebase.app(RTDBClient.appName));

  static final UpdateRemoteDataSource instance = UpdateRemoteDataSource();

  static const String _tag = 'Update';

  @override
  Future<void> reset() async {
    AppLogger.d('Resetting UpdateRemoteDataSource', tag: _tag);
  }

  bool _isNewer(String current, String latest) {
    try {
      final c = current.replaceAll(RegExp(r'[^0-9.]'), '').split('.');
      final l = latest.replaceAll(RegExp(r'[^0-9.]'), '').split('.');
      for (var i = 0; i < 3; i++) {
        final cv = int.tryParse(c.elementAtOrNull(i) ?? '0') ?? 0;
        final lv = int.tryParse(l.elementAtOrNull(i) ?? '0') ?? 0;
        if (lv > cv) return true;
        if (lv < cv) return false;
      }
      return false;
    } catch (e) {
      AppLogger.e('Version parse error', error: e, tag: _tag);
      return false;
    }
  }

  Future<UpdateInfo> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      final doc = await _firestore
          .collection(FirebasePaths.system)
          .doc(FirebasePaths.appVersion.split('/').last)
          .get()
          .timeout(const Duration(seconds: 4));

      if (!doc.exists) {
        return const UpdateInfo(
          status: UpdateInfoStatus.error,
          errorMessage: 'Update configuration not found.',
        );
      }

      final data = doc.data()!;
      final latest = data['latest'] as String? ?? '1.0.0';
      final minSupported = data['min_supported'] as String? ?? '1.0.0';
      final updateUrl = data['update_url'] as String? ?? '';
      final downloadUrl = data['download_url'] as String?;
      final forceUpdateMessage = data['force_update_message'] as String?;

      if (_isNewer(current, minSupported)) {
        return UpdateInfo(
          status: UpdateInfoStatus.forced,
          latestVersion: latest,
          releaseUrl: updateUrl,
          downloadUrl: downloadUrl,
          forceUpdateMessage: forceUpdateMessage,
        );
      } else if (_isNewer(current, latest)) {
        return UpdateInfo(
          status: UpdateInfoStatus.available,
          latestVersion: latest,
          releaseUrl: updateUrl,
          downloadUrl: downloadUrl,
        );
      } else {
        return UpdateInfo(
          status: UpdateInfoStatus.upToDate,
          latestVersion: current,
        );
      }
    } catch (e) {
      AppLogger.e('Error checking for update', error: e, tag: _tag);
      return const UpdateInfo(
        status: UpdateInfoStatus.error,
        errorMessage: 'Check failed. Verify your internet connection.',
      );
    }
  }
}
