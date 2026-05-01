import 'package:equatable/equatable.dart';

enum UsageRange {
  sevenDays(days: 7, label: '7D'),
  thirtyDays(days: 30, label: '30D'),
  ninetyDays(days: 90, label: '90D'),
  oneYear(days: 365, label: '1Y');

  final int days;
  final String label;
  const UsageRange({required this.days, required this.label});
}

abstract class UsageEvent extends Equatable {
  const UsageEvent();

  @override
  List<Object?> get props => [];
}

class LoadUsageStats extends UsageEvent {
  final bool refresh;

  const LoadUsageStats({this.refresh = false});

  @override
  List<Object?> get props => [refresh];
}

class SetDateRange extends UsageEvent {
  final UsageRange range;

  const SetDateRange(this.range);

  @override
  List<Object?> get props => [range];
}

class ExportCsv extends UsageEvent {
  const ExportCsv();
}
