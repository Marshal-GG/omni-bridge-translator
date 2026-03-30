import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:omni_bridge/features/about/domain/entities/update_result.dart';

class UpdateRemoteDataSource {
  UpdateRemoteDataSource._();
  static final UpdateRemoteDataSource instance = UpdateRemoteDataSource._();

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
      debugPrint('[UpdateRemoteDataSource] Version parse error: $e');
      return false;
    }
  }

  Future<UpdateResult> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      final docStr = await FirebaseFirestore.instance
          .collection('system')
          .doc('app_version')
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
      final forceUpdateMessage = data['force_update_message'] as String?;

      UpdateResult result;

      if (_isNewer(current, minSupported)) {
        result = UpdateResult(
          status: UpdateStatus.forced,
          latestVersion: latest,
          releaseUrl: updateUrl,
          forceUpdateMessage: forceUpdateMessage,
        );
      } else if (_isNewer(current, latest)) {
        result = UpdateResult(
          status: UpdateStatus.available,
          latestVersion: latest,
          releaseUrl: updateUrl,
        );
      } else {
        result = UpdateResult(
          status: UpdateStatus.upToDate,
          latestVersion: current,
        );
      }

      // Automatically update the global notifier if an update is found
      if (result.status == UpdateStatus.forced || result.status == UpdateStatus.available) {
        UpdateNotifier.instance.setAvailable(
          result.latestVersion ?? '',
          result.releaseUrl ?? '',
          forced: result.status == UpdateStatus.forced,
          message: result.forceUpdateMessage,
        );
      }

      return result;
    } catch (e) {
      debugPrint('[UpdateRemoteDataSource] Error: $e');
      return const UpdateResult(
        status: UpdateStatus.error,
        errorMessage: 'Check failed. Verify your internet connection.',
      );
    }
  }
}

/// Lightweight notifier so the overlay header can show a badge dot or forced UI.
class UpdateNotifier extends ValueNotifier<bool> {
  UpdateNotifier._() : super(false);
  static final UpdateNotifier instance = UpdateNotifier._();

  String? latestVersion;
  String? releaseUrl;
  String? forceUpdateMessage;
  bool isForced = false;

  void setAvailable(String version, String url, {bool forced = false, String? message}) {
    latestVersion = version;
    releaseUrl = url;
    isForced = forced;
    forceUpdateMessage = message;
    value = true;
  }

  void dismiss() {
    if (!isForced) {
      value = false;
    }
  }
}
