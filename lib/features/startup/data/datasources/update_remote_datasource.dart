import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:omni_bridge/core/constants/firebase_paths.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';
import 'package:omni_bridge/core/network/rtdb_client.dart';
import 'package:omni_bridge/core/data/interfaces/resettable.dart';
import 'package:omni_bridge/features/about/domain/entities/update_result.dart';
import 'package:omni_bridge/features/startup/presentation/notifiers/update_notifier.dart';

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
    // No local state to clear in this data source, but implements interface for consistency
    AppLogger.d('Resetting UpdateRemoteDataSource', tag: _tag);
  }

  /// Compares semver strings. Returns true if [latest] is newer than [current].
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

  Future<UpdateResult> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      final docStr = await _firestore
          .collection(FirebasePaths.system)
          .doc(FirebasePaths.appVersion.split('/').last)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!docStr.exists) {
        return const UpdateResult(
          status: UpdateStatus.error,
          errorMessage: 'Update configuration not found.',
        );
      }

      final data = docStr.data()!;
      final latest = data['latest'] as String? ?? '1.0.0';
      final minSupported = data['min_supported'] as String? ?? '1.0.0';
      final updateUrl = data['update_url'] as String? ?? '';
      final downloadUrl = data['download_url'] as String?;
      final forceUpdateMessage = data['force_update_message'] as String?;

      UpdateResult result;

      if (_isNewer(current, minSupported)) {
        result = UpdateResult(
          status: UpdateStatus.forced,
          latestVersion: latest,
          releaseUrl: updateUrl,
          downloadUrl: downloadUrl,
          forceUpdateMessage: forceUpdateMessage,
        );
      } else if (_isNewer(current, latest)) {
        result = UpdateResult(
          status: UpdateStatus.available,
          latestVersion: latest,
          releaseUrl: updateUrl,
          downloadUrl: downloadUrl,
        );
      } else {
        result = UpdateResult(
          status: UpdateStatus.upToDate,
          latestVersion: current,
        );
      }

      // Automatically update the global notifier if an update is found
      if (result.status == UpdateStatus.forced ||
          result.status == UpdateStatus.available) {
        UpdateNotifier.instance.setAvailable(
          result.latestVersion ?? '',
          result.releaseUrl ?? '',
          download: result.downloadUrl,
          forced: result.status == UpdateStatus.forced,
          message: result.forceUpdateMessage,
        );
      }

      return result;
    } catch (e) {
      AppLogger.e('Error checking for update', error: e, tag: _tag);
      return const UpdateResult(
        status: UpdateStatus.error,
        errorMessage: 'Check failed. Verify your internet connection.',
      );
    }
  }
}
