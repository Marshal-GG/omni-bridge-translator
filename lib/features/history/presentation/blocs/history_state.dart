import 'package:equatable/equatable.dart';
import 'package:omni_bridge/features/history/domain/entities/history_entry.dart';
import 'package:omni_bridge/features/subscription/data/models/subscription_dto.dart';

abstract class HistoryState extends Equatable {
  const HistoryState();

  @override
  List<Object?> get props => [];
}

class HistoryLoading extends HistoryState {}

class HistoryLoaded extends HistoryState {
  final List<HistoryEntry> liveEntries;
  final List<HistoryEntry> chunkedEntries;
  final SubscriptionStatus subscriptionStatus;

  const HistoryLoaded({
    required this.liveEntries,
    required this.chunkedEntries,
    required this.subscriptionStatus,
  });

  @override
  List<Object?> get props => [liveEntries, chunkedEntries, subscriptionStatus];
}
