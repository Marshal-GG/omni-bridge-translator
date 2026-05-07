import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/features/history/domain/repositories/i_history_repository.dart';
import 'package:omni_bridge/features/history/domain/usecases/get_live_history_usecase.dart';
import 'package:omni_bridge/features/history/domain/usecases/get_chunked_history_usecase.dart';
import 'package:omni_bridge/features/history/domain/usecases/clear_history_usecase.dart';
import 'package:omni_bridge/features/subscription/domain/repositories/i_subscription_repository.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import 'package:omni_bridge/features/history/domain/entities/history_entry.dart';
import 'history_event.dart';
import 'history_state.dart';

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final GetLiveHistoryUseCase _getLiveHistoryUseCase;
  final GetChunkedHistoryUseCase _getChunkedHistoryUseCase;
  final ClearHistoryUseCase _clearHistoryUseCase;
  final ISubscriptionRepository _subscriptionDataSource;
  final IHistoryRepository? _historyRepository;

  late final ValueListenable<List<HistoryEntry>> _liveHistoryListenable;
  late final ValueListenable<List<HistoryEntry>> _chunkedHistoryListenable;
  late final StreamSubscription<QuotaStatus> _subscriptionStreamSub;

  List<HistoryEntry> _currentLive = [];
  List<HistoryEntry> _currentChunked = [];
  QuotaStatus? _currentSubStatus;
  String _search = '';
  String _langFilter = 'all';

  HistoryBloc({
    required GetLiveHistoryUseCase getLiveHistoryUseCase,
    required GetChunkedHistoryUseCase getChunkedHistoryUseCase,
    required ClearHistoryUseCase clearHistoryUseCase,
    required ISubscriptionRepository subscriptionDataSource,
    IHistoryRepository? historyRepository,
  }) : _getLiveHistoryUseCase = getLiveHistoryUseCase,
       _getChunkedHistoryUseCase = getChunkedHistoryUseCase,
       _clearHistoryUseCase = clearHistoryUseCase,
       _subscriptionDataSource = subscriptionDataSource,
       _historyRepository = historyRepository,
       super(HistoryLoading()) {
    on<LoadHistoryEvent>(_onLoadHistory);
    on<HistoryUpdatedEvent>(_onHistoryUpdated);
    on<ClearHistoryEvent>(_onClearHistory);
    on<HistorySearchChanged>(_onSearchChanged);
    on<HistoryLangFilterChanged>(_onLangFilterChanged);
    on<HistoryEntryDeleted>(_onEntryDeleted);

    _liveHistoryListenable = _getLiveHistoryUseCase();
    _chunkedHistoryListenable = _getChunkedHistoryUseCase();

    _liveHistoryListenable.addListener(_onLiveHistoryChanged);
    _chunkedHistoryListenable.addListener(_onChunkedHistoryChanged);

    _subscriptionStreamSub = _subscriptionDataSource.statusStream.listen((
      status,
    ) {
      add(HistoryUpdatedEvent(subscriptionStatus: status));
    });
  }

  HistoryLoaded? _buildLoaded() {
    if (_currentSubStatus == null) return null;
    return HistoryLoaded(
      liveEntries: _currentLive,
      chunkedEntries: _currentChunked,
      subscriptionStatus: _currentSubStatus!,
      search: _search,
      langFilter: _langFilter,
    );
  }

  void _onLoadHistory(LoadHistoryEvent event, Emitter<HistoryState> emit) {
    _currentLive = _liveHistoryListenable.value;
    _currentChunked = _chunkedHistoryListenable.value;
    _currentSubStatus = _subscriptionDataSource.currentStatus;

    final loaded = _buildLoaded();
    if (loaded != null) emit(loaded);
  }

  void _onHistoryUpdated(
    HistoryUpdatedEvent event,
    Emitter<HistoryState> emit,
  ) {
    if (event.liveEntries != null) _currentLive = event.liveEntries!;
    if (event.chunkedEntries != null) _currentChunked = event.chunkedEntries!;
    if (event.subscriptionStatus != null) {
      _currentSubStatus = event.subscriptionStatus!;
    }

    final loaded = _buildLoaded();
    if (loaded != null) emit(loaded);
  }

  void _onClearHistory(ClearHistoryEvent event, Emitter<HistoryState> emit) {
    _clearHistoryUseCase();
  }

  void _onSearchChanged(
    HistorySearchChanged event,
    Emitter<HistoryState> emit,
  ) {
    _search = event.query;
    final loaded = _buildLoaded();
    if (loaded != null) emit(loaded);
  }

  void _onLangFilterChanged(
    HistoryLangFilterChanged event,
    Emitter<HistoryState> emit,
  ) {
    _langFilter = event.code;
    final loaded = _buildLoaded();
    if (loaded != null) emit(loaded);
  }

  void _onEntryDeleted(
    HistoryEntryDeleted event,
    Emitter<HistoryState> emit,
  ) {
    _historyRepository?.removeEntry(event.entry);
    // The notifier listener will re-emit with the trimmed list.
  }

  void _onLiveHistoryChanged() {
    add(HistoryUpdatedEvent(liveEntries: _liveHistoryListenable.value));
  }

  void _onChunkedHistoryChanged() {
    add(HistoryUpdatedEvent(chunkedEntries: _chunkedHistoryListenable.value));
  }

  @override
  Future<void> close() {
    _liveHistoryListenable.removeListener(_onLiveHistoryChanged);
    _chunkedHistoryListenable.removeListener(_onChunkedHistoryChanged);
    _subscriptionStreamSub.cancel();
    return super.close();
  }
}
