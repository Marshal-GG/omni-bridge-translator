import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:omni_bridge/core/di/di.dart';
import 'package:omni_bridge/features/startup/domain/entities/update_info.dart';
import 'package:omni_bridge/features/startup/domain/repositories/i_update_repository.dart';
import 'package:omni_bridge/features/startup/presentation/notifiers/update_notifier.dart';

/// Monitors internet connectivity and triggers background tasks (like update checks)
/// when the device returns online.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isFirstCheck = true;

  /// Starts listening for connectivity changes.
  void init() {
    _subscription?.cancel();
    _subscription = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityChange,
    );
    debugPrint('[ConnectivityService] Listener initialized.');
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);

    if (_isFirstCheck) {
      _isFirstCheck = false;
      return;
    }

    if (hasNetwork) {
      debugPrint(
        '[ConnectivityService] Internet connection restored. Retrying background tasks...',
      );

      Future.delayed(const Duration(seconds: 3), () async {
        try {
          final result = await sl<IUpdateRepository>().checkForUpdate();

          if (result.status == UpdateInfoStatus.forced ||
              result.status == UpdateInfoStatus.available) {
            UpdateNotifier.instance.setAvailable(
              result.latestVersion ?? '',
              result.releaseUrl ?? '',
              download: result.downloadUrl,
              forced: result.status == UpdateInfoStatus.forced,
              message: result.forceUpdateMessage,
            );
          }

          debugPrint(
            '[ConnectivityService] Background update check completed: ${result.status}',
          );
        } catch (e) {
          debugPrint(
            '[ConnectivityService] Background update check failed: $e',
          );
        }
      });
    } else {
      debugPrint('[ConnectivityService] Device went offline.');
    }
  }

  /// Stops the listener.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
