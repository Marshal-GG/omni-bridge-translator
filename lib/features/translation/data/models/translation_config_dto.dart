class TranslationConfig {
  final List<String> availableEngines;
  final String defaultEngine;
  final Map<String, String> engineNames;
  final Map<String, List<String>> engineLanguages;
  final bool fallbackEnabled;

  const TranslationConfig({
    required this.availableEngines,
    required this.defaultEngine,
    required this.engineNames,
    required this.engineLanguages,
    this.fallbackEnabled = true,
  });

  factory TranslationConfig.fromJson(Map<String, dynamic> json) {
    return TranslationConfig(
      availableEngines: List<String>.from(json['available_engines'] ?? []),
      defaultEngine: json['default_engine'] as String? ?? 'google',
      engineNames: Map<String, String>.from(json['engine_names'] ?? {}),
      engineLanguages:
          (json['engine_languages'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, List<String>.from(v)),
          ) ??
          {},
      fallbackEnabled: json['fallback_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'available_engines': availableEngines,
      'default_engine': defaultEngine,
      'engine_names': engineNames,
      'engine_languages': engineLanguages,
      'fallback_enabled': fallbackEnabled,
    };
  }
}
