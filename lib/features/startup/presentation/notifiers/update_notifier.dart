import 'package:flutter/foundation.dart';

/// Lightweight notifier so the overlay header can show a badge dot or forced UI.
class UpdateNotifier extends ValueNotifier<bool> {
  UpdateNotifier._() : super(false);
  static final UpdateNotifier instance = UpdateNotifier._();

  String? latestVersion;
  String? releaseUrl;
  String? downloadUrl;
  String? forceUpdateMessage;
  bool isForced = false;

  void setAvailable(
    String version,
    String url, {
    String? download,
    bool forced = false,
    String? message,
  }) {
    latestVersion = version;
    releaseUrl = url;
    downloadUrl = download;
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
