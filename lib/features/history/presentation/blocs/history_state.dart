import 'package:equatable/equatable.dart';
import 'package:omni_bridge/features/history/domain/entities/history_entry.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';

abstract class HistoryState extends Equatable {
  const HistoryState();

  @override
  List<Object?> get props => [];
}

class HistoryLoading extends HistoryState {}

class HistoryLoaded extends HistoryState {
  final List<HistoryEntry> liveEntries;
  final List<HistoryEntry> chunkedEntries;
  final QuotaStatus subscriptionStatus;

  const HistoryLoaded({
    required this.liveEntries,
    required this.chunkedEntries,
    required this.subscriptionStatus,
  });

  @override
  List<Object?> get props => [liveEntries, chunkedEntries, subscriptionStatus];
}
