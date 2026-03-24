import 'package:equatable/equatable.dart';

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
