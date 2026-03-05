import 'package:flutter/foundation.dart';

/// Checks if Firebase Crashlytics is natively supported on the current platform.
bool get isCrashlyticsSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Checks if Firebase Analytics is natively supported on the current platform.
bool get isAnalyticsSupported =>
    kIsWeb ||
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);
