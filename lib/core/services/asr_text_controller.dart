import 'dart:async';
import 'package:flutter/foundation.dart';

/// Holds the latest ASR text for the overlay UI
/// Uses ValueNotifier because it's perfect for live captions
class AsrTextController extends ValueNotifier<String> {
  final List<String> _finalSegments = [];
  String _interimText = "";
  String _targetValue = "";
  Timer? _typingTimer;

  // Safety fallback: characters that definitely won't fit in 2 lines.
  // We prefer the UI-driven Precise Line Trimming, but this prevents memory leaks.
  static const int _maxChars = 2000;

  AsrTextController() : super("Waiting for audio...");

  void updateInterim(String text) {
    _interimText = text.trim();
    _rebuildTarget();
  }

  void commitFinal(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (_targetValue == "Waiting for audio...") {
      _targetValue = "";
      value = "";
    }

    _finalSegments.add(trimmed);
    _interimText = "";

    _trimSegments();
    _rebuildTarget();
  }

  int _revision = 0;
  int get revision => _revision;

  void _trimSegments() {
    int totalLen = _finalSegments.fold(
      0,
      (sum, s) => sum + s.length + (sum > 0 ? 1 : 0),
    );
    if (totalLen > _maxChars) {
      // Fallback: trim until under limit
      while (_finalSegments.length > 1 && totalLen > _maxChars) {
        String removed = _finalSegments.removeAt(0);
        totalLen -= (removed.length + 1);
        _revision++;
      }
    }
  }

  /// Precisely removes the first [count] characters from the final segments.
  /// Used by the UI layer when text measurement detects a line overflow.
  void trimBy(int count) {
    if (count <= 0 || _finalSegments.isEmpty) return;

    // Collage segments and trim precisely
    final full = _finalSegments.join(" ");
    if (full.length <= count) {
      _finalSegments.clear();
    } else {
      String newFull = full.substring(count);
      // If we trimmed mid-word or up to a space, clean up leading space
      newFull = newFull.trimLeft();

      _finalSegments.clear();
      if (newFull.isNotEmpty) {
        _finalSegments.add(newFull);
      }
    }

    _revision++;
    _rebuildTarget();
  }

  void _rebuildTarget() {
    final history = _finalSegments.join(" ");
    if (_interimText.isEmpty) {
      _targetValue = history.isEmpty ? "Waiting for audio..." : history;
    } else {
      _targetValue = history.isEmpty ? _interimText : "$history $_interimText";
    }

    if (_targetValue == "Waiting for audio...") {
      value = _targetValue;
      _stopTyping();
    } else {
      _startTyping();
    }
  }

  void _startTyping() {
    if (_typingTimer != null) return;

    _typingTimer = Timer.periodic(const Duration(milliseconds: 15), (timer) {
      if (value == _targetValue) {
        _stopTyping();
        return;
      }

      // If current value is no longer a prefix of target (due to trimming)
      // just snap it to avoid jarring jump.
      if (!_targetValue.startsWith(value)) {
        value = _targetValue.length > value.length
            ? _targetValue.substring(0, value.length)
            : _targetValue;
      }

      // Type 4 chars at a time for "super fast" feel
      const int charsToType = 4;
      int remaining = _targetValue.length - value.length;
      if (remaining > 0) {
        int take = remaining < charsToType ? remaining : charsToType;
        value = _targetValue.substring(0, value.length + take);
      }
    });
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    _typingTimer = null;
  }

  void clear() {
    _stopTyping();
    _finalSegments.clear();
    _interimText = "";
    _targetValue = "Waiting for audio...";
    value = _targetValue;
  }

  void showSystemMessage(String text) {
    _interimText = "";
    _targetValue = text;
    value = text;
    _stopTyping();
  }

  @override
  void dispose() {
    _stopTyping();
    super.dispose();
  }
}

/// Global singleton (simple & effective)
final AsrTextController asrTextController = AsrTextController();
