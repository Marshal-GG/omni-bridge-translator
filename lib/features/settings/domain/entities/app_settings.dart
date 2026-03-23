import 'package:equatable/equatable.dart';

class AppSettings extends Equatable {
  final String targetLang;
  final String sourceLang;
  final bool useMic;
  final double fontSize;
  final bool isBold;
  final double opacity;
  final int? inputDeviceIndex;
  final int? outputDeviceIndex;
  final double desktopVolume;
  final double micVolume;
  final String translationModel;
  final String apiKey;
  final String transcriptionModel;

  const AppSettings({
    required this.targetLang,
    required this.sourceLang,
    required this.useMic,
    required this.fontSize,
    required this.isBold,
    required this.opacity,
    this.inputDeviceIndex,
    this.outputDeviceIndex,
    required this.desktopVolume,
    required this.micVolume,
    required this.translationModel,
    required this.apiKey,
    required this.transcriptionModel,
  });

  factory AppSettings.initial() {
    return const AppSettings(
      targetLang: 'en',
      sourceLang: 'auto',
      useMic: false,
      fontSize: 18.0,
      isBold: false,
      opacity: 0.85,
      inputDeviceIndex: null,
      outputDeviceIndex: null,
      desktopVolume: 1.0,
      micVolume: 1.0,

      /// The translation model to use (e.g., 'google', 'google_api', 'mymemory', 'riva', 'llama')
      translationModel: 'google',
      apiKey: '',
      transcriptionModel: 'online',
    );
  }

  AppSettings copyWith({
    String? targetLang,
    String? sourceLang,
    bool? useMic,
    double? fontSize,
    bool? isBold,
    double? opacity,
    int? inputDeviceIndex,
    int? outputDeviceIndex,
    bool clearInputDevice = false,
    bool clearOutputDevice = false,
    double? desktopVolume,
    double? micVolume,
    String? translationModel,
    String? apiKey,
    String? transcriptionModel,
  }) {
    return AppSettings(
      targetLang: targetLang ?? this.targetLang,
      sourceLang: sourceLang ?? this.sourceLang,
      useMic: useMic ?? this.useMic,
      fontSize: fontSize ?? this.fontSize,
      isBold: isBold ?? this.isBold,
      opacity: opacity ?? this.opacity,
      inputDeviceIndex: clearInputDevice
          ? null
          : (inputDeviceIndex ?? this.inputDeviceIndex),
      outputDeviceIndex: clearOutputDevice
          ? null
          : (outputDeviceIndex ?? this.outputDeviceIndex),
      desktopVolume: desktopVolume ?? this.desktopVolume,
      micVolume: micVolume ?? this.micVolume,
      translationModel: translationModel ?? this.translationModel,
      apiKey: apiKey ?? this.apiKey,
      transcriptionModel: transcriptionModel ?? this.transcriptionModel,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      targetLang: json['targetLang'] as String? ?? 'en',
      sourceLang: json['sourceLang'] as String? ?? 'auto',
      useMic: json['useMic'] as bool? ?? false,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18.0,
      isBold: json['isBold'] as bool? ?? false,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.85,
      inputDeviceIndex: json['inputDeviceIndex'] as int?,
      outputDeviceIndex: json['outputDeviceIndex'] as int?,
      desktopVolume: (json['desktopVolume'] as num?)?.toDouble() ?? 1.0,
      micVolume: (json['micVolume'] as num?)?.toDouble() ?? 1.0,
      translationModel: json['translationModel'] as String? ?? 'google',
      apiKey: json['apiKey'] as String? ?? '',
      transcriptionModel: json['transcriptionModel'] as String? ?? 'online',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'targetLang': targetLang,
      'sourceLang': sourceLang,
      'useMic': useMic,
      'fontSize': fontSize,
      'isBold': isBold,
      'opacity': opacity,
      'inputDeviceIndex': inputDeviceIndex,
      'outputDeviceIndex': outputDeviceIndex,
      'desktopVolume': desktopVolume,
      'micVolume': micVolume,
      'translationModel': translationModel,
      'apiKey': apiKey,
      'transcriptionModel': transcriptionModel,
    };
  }

  @override
  List<Object?> get props => [
        targetLang,
        sourceLang,
        useMic,
        fontSize,
        isBold,
        opacity,
        inputDeviceIndex,
        outputDeviceIndex,
        desktopVolume,
        micVolume,
        translationModel,
        apiKey,
        transcriptionModel,
      ];


}
