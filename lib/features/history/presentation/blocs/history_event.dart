import 'package:equatable/equatable.dart';
import 'package:omni_bridge/features/history/domain/entities/history_entry.dart';
import 'package:omni_bridge/features/subscription/data/models/subscription_dto.dart';

abstract class HistoryEvent extends Equatable {
  const HistoryEvent();

  @override
  List<Object?> get props => [];
}

class LoadHistoryEvent extends HistoryEvent {}

class HistoryUpdatedEvent extends HistoryEvent {
  final List<HistoryEntry>? liveEntries;
  final List<HistoryEntry>? chunkedEntries;
  final SubscriptionStatus? subscriptionStatus;

  const HistoryUpdatedEvent({
    this.liveEntries,
    this.chunkedEntries,
    this.subscriptionStatus,
  });

  @override
  List<Object?> get props => [liveEntries, chunkedEntries, subscriptionStatus];
}

class ClearHistoryEvent extends HistoryEvent {}
