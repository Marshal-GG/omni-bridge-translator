import 'package:equatable/equatable.dart';
import 'package:omni_bridge/features/history/domain/entities/history_entry.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';

abstract class HistoryEvent extends Equatable {
  const HistoryEvent();

  @override
  List<Object?> get props => [];
}

class LoadHistoryEvent extends HistoryEvent {}

class HistoryUpdatedEvent extends HistoryEvent {
  final List<HistoryEntry>? liveEntries;
  final List<HistoryEntry>? chunkedEntries;
  final QuotaStatus? subscriptionStatus;

  const HistoryUpdatedEvent({
    this.liveEntries,
    this.chunkedEntries,
    this.subscriptionStatus,
  });

  @override
  List<Object?> get props => [liveEntries, chunkedEntries, subscriptionStatus];
}

class ClearHistoryEvent extends HistoryEvent {}

/// User typed in the search box. Empty string clears the filter.
class HistorySearchChanged extends HistoryEvent {
  final String query;
  const HistorySearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

/// User picked a language pill. `'all'` removes the language filter.
class HistoryLangFilterChanged extends HistoryEvent {
  final String code;
  const HistoryLangFilterChanged(this.code);

  @override
  List<Object?> get props => [code];
}

/// User deleted a single entry. The bloc forwards this to
/// `IHistoryRepository.removeEntry` so the source notifier emits the
/// trimmed list (otherwise the next add would re-emit the deleted row).
class HistoryEntryDeleted extends HistoryEvent {
  final HistoryEntry entry;
  const HistoryEntryDeleted(this.entry);

  @override
  List<Object?> get props => [entry];
}
