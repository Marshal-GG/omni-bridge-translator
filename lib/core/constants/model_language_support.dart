library;

/// Single source of truth for which translation and ASR models support which
/// languages.
///
/// Update this file when adding new models or languages.
/// Both [settings_bloc.dart] (compatibility validation) and the UI (badges,
/// tooltips) should import from here.
///
/// A null set means the model supports ALL app languages.
/// An explicit `Set<String>` lists the only supported language codes.

// ── Translation models ────────────────────────────────────────────────────────

/// Riva NMT — both source AND target must be in this set.
const Set<String> rivaTranslationLangs = {
  'en', 'de', 'es', 'fr', 'pt', 'ru', 'zh', 'ja', 'ko', 'ar',
};

/// Google Translate (free) — supports all app languages.
const Set<String>? googleFreeLangs = null;

/// Google Cloud Translation API — supports all app languages.
const Set<String>? googleCloudLangs = null;

/// MyMemory — supports all app languages.
const Set<String>? myMemoryLangs = null;

/// Llama 3.1 8B via NVIDIA NIM — LLM, supports all app languages.
const Set<String>? llamaLangs = null;

// ── ASR / Transcription models ────────────────────────────────────────────────

/// Riva Parakeet ASR — app-level codes (not BCP-47) it covers.
/// Canary handles the remainder; combined they cover all app languages.
const Set<String> rivaAsrLangs = {
  'en', 'es', 'fr', 'de', 'it', 'ar', 'ko', 'pt', 'ru',
  'hi', 'nl', 'da', 'cs', 'pl', 'sv', 'th', 'tr', 'he', 'bn',
};

/// Whisper offline — supports all app languages.
const Set<String>? whisperLangs = null;

/// Google Speech Recognition (online) — supports all app languages.
const Set<String>? googleSrLangs = null;

// ── Lookup helper ─────────────────────────────────────────────────────────────

/// Returns the supported language set for a given translation [model] key,
/// or null if the model is unrestricted.
Set<String>? translationLangsFor(String model) {
  switch (model) {
    case 'riva':       return rivaTranslationLangs;
    case 'google':     return googleFreeLangs;
    case 'google_api': return googleCloudLangs;
    case 'mymemory':   return myMemoryLangs;
    case 'llama':      return llamaLangs;
    default:           return null;
  }
}

/// Returns a human-readable comma-separated list of supported languages
/// for the given translation [model], or "All languages" if unrestricted.
String translationLangSupportLabel(String model) {
  final langs = translationLangsFor(model);
  if (langs == null) return 'All languages';
  return langs.join(', ');
}

/// Returns an error string if [model] cannot translate [source] → [target],
/// or null if the combination is valid.
///
/// Pass [source] == 'auto' when the user has selected auto-detect.
/// Pass [target] == 'none' for transcription-only mode (always valid).
String? translationCompatibilityError(
  String model,
  String source,
  String target,
) {
  if (target == 'none') return null;

  final supported = translationLangsFor(model);
  if (supported == null) return null; // unrestricted model

  final srcOk = source == 'auto' || supported.contains(source);
  final tgtOk = supported.contains(target);
  if (srcOk && tgtOk) return null;

  final unsupported = [
    if (!srcOk) 'source "$source"',
    if (!tgtOk) 'target "$target"',
  ];
  return '${_modelLabel(model)} does not support ${unsupported.join(' or ')}. '
      'Supported: ${translationLangSupportLabel(model)}.';
}

String _modelLabel(String model) => switch (model) {
      'riva'       => 'Riva NMT',
      'google'     => 'Google Translate',
      'google_api' => 'Google Cloud',
      'mymemory'   => 'MyMemory',
      'llama'      => 'Llama 3.1 8B',
      _            => model,
    };
