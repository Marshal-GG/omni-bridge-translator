import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

enum UpdateStatus { idle, checking, upToDate, available, error }

class UpdateResult {
  final UpdateStatus status;
  final String? latestVersion;
  final String? releaseUrl;
  final String? errorMessage;

  const UpdateResult({
    required this.status,
    this.latestVersion,
    this.releaseUrl,
    this.errorMessage,
  });
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const _owner = 'Marshal-GG';
  static const _repo = 'omni-bridge-translator';
  static const _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

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
    } catch (_) {
      return false;
    }
  }

  Future<UpdateResult> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      final response = await http
          .get(Uri.parse(_apiUrl), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 404) {
        return const UpdateResult(
          status: UpdateStatus.error,
          errorMessage: 'No releases published yet.',
        );
      }
      if (response.statusCode != 200) {
        return UpdateResult(
          status: UpdateStatus.error,
          errorMessage: 'GitHub returned ${response.statusCode}.',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String? ?? '').replaceAll('v', '');
      final htmlUrl = data['html_url'] as String? ?? _apiUrl;

      if (_isNewer(current, tagName)) {
        return UpdateResult(
          status: UpdateStatus.available,
          latestVersion: tagName,
          releaseUrl: htmlUrl,
        );
      }

      return UpdateResult(
        status: UpdateStatus.upToDate,
        latestVersion: current,
      );
    } catch (e) {
      debugPrint('[UpdateService] Error: $e');
      return UpdateResult(
        status: UpdateStatus.error,
        errorMessage: 'Check failed. Verify your internet connection.',
      );
    }
  }
}

/// Lightweight notifier so the overlay header can show a badge dot.
class UpdateNotifier extends ValueNotifier<bool> {
  UpdateNotifier._() : super(false);
  static final UpdateNotifier instance = UpdateNotifier._();

  String? latestVersion;
  String? releaseUrl;

  void setAvailable(String version, String url) {
    latestVersion = version;
    releaseUrl = url;
    value = true;
  }

  void dismiss() => value = false;
}
