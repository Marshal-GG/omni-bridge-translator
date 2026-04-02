import 'package:equatable/equatable.dart';

class SystemConfig extends Equatable {
  final String rivaTranslationFunctionId;
  final String rivaAsrParakeetFunctionId;
  final String rivaAsrCanaryFunctionId;
  final Object? googleCredentials;

  const SystemConfig({
    required this.rivaTranslationFunctionId,
    required this.rivaAsrParakeetFunctionId,
    required this.rivaAsrCanaryFunctionId,
    this.googleCredentials,
  });

  factory SystemConfig.initial() {
    return const SystemConfig(
      rivaTranslationFunctionId: '',
      rivaAsrParakeetFunctionId: '',
      rivaAsrCanaryFunctionId: '',
      googleCredentials: null,
    );
  }

  factory SystemConfig.fromMap(Map<String, dynamic> map) {
    return SystemConfig(
      rivaTranslationFunctionId:
          map['riva_nmt_fid'] ?? map['rivaTranslationFunctionId'] ?? '',
      rivaAsrParakeetFunctionId:
          map['riva_parakeet_fid'] ?? map['rivaAsrParakeetFunctionId'] ?? '',
      rivaAsrCanaryFunctionId:
          map['riva_canary_fid'] ?? map['rivaAsrCanaryFunctionId'] ?? '',
      googleCredentials:
          map['google_credentials'] ?? (map.containsKey('type') ? map : null),
    );
  }

  factory SystemConfig.empty() {
    return const SystemConfig(
      rivaTranslationFunctionId: '',
      rivaAsrParakeetFunctionId: '',
      rivaAsrCanaryFunctionId: '',
      googleCredentials: null,
    );
  }

  SystemConfig copyWith({
    String? rivaTranslationFunctionId,
    String? rivaAsrParakeetFunctionId,
    String? rivaAsrCanaryFunctionId,
    dynamic googleCredentials,
  }) {
    return SystemConfig(
      rivaTranslationFunctionId:
          rivaTranslationFunctionId ?? this.rivaTranslationFunctionId,
      rivaAsrParakeetFunctionId:
          rivaAsrParakeetFunctionId ?? this.rivaAsrParakeetFunctionId,
      rivaAsrCanaryFunctionId:
          rivaAsrCanaryFunctionId ?? this.rivaAsrCanaryFunctionId,
      googleCredentials: googleCredentials ?? this.googleCredentials,
    );
  }

  @override
  List<Object?> get props => [
    rivaTranslationFunctionId,
    rivaAsrParakeetFunctionId,
    rivaAsrCanaryFunctionId,
    googleCredentials,
  ];
}
