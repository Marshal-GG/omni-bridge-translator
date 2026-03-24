import 'package:equatable/equatable.dart';

class DailyUsageRecord extends Equatable {
  final DateTime date;
  final int totalTokens;
  final Map<String, int> engineTokens;

  const DailyUsageRecord({
    required this.date,
    required this.totalTokens,
    required this.engineTokens,
  });

  @override
  List<Object?> get props => [date, totalTokens, engineTokens];
}
