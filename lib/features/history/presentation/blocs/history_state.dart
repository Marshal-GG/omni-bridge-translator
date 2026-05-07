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

  /// Current search query — applied to both transcription and translation
  /// (case-insensitive). Empty means no filter.
  final String search;

  /// Active language filter — `'all'` or an ISO source-language code.
  final String langFilter;

  const HistoryLoaded({
    required this.liveEntries,
    required this.chunkedEntries,
    required this.subscriptionStatus,
    this.search = '',
    this.langFilter = 'all',
  });

  HistoryLoaded copyWith({
    List<HistoryEntry>? liveEntries,
    List<HistoryEntry>? chunkedEntries,
    QuotaStatus? subscriptionStatus,
    String? search,
    String? langFilter,
  }) {
    return HistoryLoaded(
      liveEntries: liveEntries ?? this.liveEntries,
      chunkedEntries: chunkedEntries ?? this.chunkedEntries,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      search: search ?? this.search,
      langFilter: langFilter ?? this.langFilter,
    );
  }

  @override
  List<Object?> get props => [
    liveEntries,
    chunkedEntries,
    subscriptionStatus,
    search,
    langFilter,
  ];
}
