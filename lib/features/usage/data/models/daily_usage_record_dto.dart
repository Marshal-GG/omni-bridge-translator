import 'package:omni_bridge/features/usage/domain/entities/daily_usage_record.dart';

class DailyUsageRecordDto extends DailyUsageRecord {
  const DailyUsageRecordDto({
    required super.date,
    required super.totalTokens,
    required super.engineTokens,
  });

  factory DailyUsageRecordDto.fromJson(String dateStr, Map<String, dynamic> json) {
    final engineTokens = <String, int>{};
    final modelsData = json['models'] as Map<String, dynamic>? ?? {};
    
    modelsData.forEach((engine, val) {
      if (val is Map<String, dynamic>) {
        engineTokens[engine] = (val['tokens'] as num?)?.toInt() ?? 0;
      }
    });

    return DailyUsageRecordDto(
      date: DateTime.parse(dateStr),
      totalTokens: (json['tokens'] as num?)?.toInt() ?? 0,
      engineTokens: engineTokens,
    );
  }
}
