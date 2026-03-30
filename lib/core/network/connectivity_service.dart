import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:omni_bridge/features/startup/data/datasources/update_remote_datasource.dart';
import 'package:omni_bridge/features/about/domain/entities/update_result.dart';

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
    _subscription = Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);
    debugPrint('[ConnectivityService] Listener initialized.');
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    
    // If it's the first result (usually triggered immediately on listen), 
    // we ignore it to avoid double-checking what AppInitializer already did.
    if (_isFirstCheck) {
      _isFirstCheck = false;
      return;
    }

    if (hasNetwork) {
      debugPrint('[ConnectivityService] Internet connection restored. Retrying background tasks...');
      
      // Delay slightly to let the OS fully establish the data path
      Future.delayed(const Duration(seconds: 3), () async {
        try {
          final result = await UpdateRemoteDataSource.instance.checkForUpdate();
          
          // If we find a forced update or a new available version, UpdateRemoteDataSource.instance.checkForUpdate()
          // already notifies UpdateNotifier.instance, which the UI reflects.
          if (result.status == UpdateStatus.forced || result.status == UpdateStatus.available) {
             UpdateNotifier.instance.setAvailable(
              result.latestVersion ?? '',
              result.releaseUrl ?? '',
              forced: result.status == UpdateStatus.forced,
              message: result.forceUpdateMessage,
            );
          }
          
          debugPrint('[ConnectivityService] Background update check completed: ${result.status}');
        } catch (e) {
          debugPrint('[ConnectivityService] Background update check failed: $e');
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
