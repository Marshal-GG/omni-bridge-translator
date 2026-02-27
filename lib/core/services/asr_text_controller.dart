import 'package:flutter/foundation.dart';

/// Holds the latest ASR text for the overlay UI
/// Uses ValueNotifier because it's perfect for live captions
class AsrTextController extends ValueNotifier<String> {
  AsrTextController() : super("Waiting for audio...");

  void updateInterim(String text) {
    if (text.isEmpty) return;
    value = text;
  }

  void commitFinal(String text) {
    if (text.isEmpty) return;
    value = text;
  }

  void clear() {
    value = "";
  }
}

/// Global singleton (simple & effective)
final AsrTextController asrTextController = AsrTextController();
