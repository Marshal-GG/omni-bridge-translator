import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/features/history/domain/usecases/get_live_history_usecase.dart';
import 'package:omni_bridge/features/history/domain/usecases/get_chunked_history_usecase.dart';
import 'package:omni_bridge/features/history/domain/usecases/clear_history_usecase.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:omni_bridge/features/subscription/data/models/subscription_dto.dart';
import 'package:omni_bridge/features/history/domain/entities/history_entry.dart';
import 'history_event.dart';
import 'history_state.dart';

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final GetLiveHistoryUseCase _getLiveHistoryUseCase;
  final GetChunkedHistoryUseCase _getChunkedHistoryUseCase;
  final ClearHistoryUseCase _clearHistoryUseCase;
  final SubscriptionRemoteDataSource _subscriptionDataSource;

  late final ValueListenable<List<HistoryEntry>> _liveHistoryListenable;
  late final ValueListenable<List<HistoryEntry>> _chunkedHistoryListenable;
  late final StreamSubscription<SubscriptionStatus> _subscriptionStreamSub;

  List<HistoryEntry> _currentLive = [];
  List<HistoryEntry> _currentChunked = [];
  SubscriptionStatus? _currentSubStatus;

  HistoryBloc({
    required GetLiveHistoryUseCase getLiveHistoryUseCase,
    required GetChunkedHistoryUseCase getChunkedHistoryUseCase,
    required ClearHistoryUseCase clearHistoryUseCase,
    required SubscriptionRemoteDataSource subscriptionDataSource,
  })  : _getLiveHistoryUseCase = getLiveHistoryUseCase,
        _getChunkedHistoryUseCase = getChunkedHistoryUseCase,
        _clearHistoryUseCase = clearHistoryUseCase,
        _subscriptionDataSource = subscriptionDataSource,
        super(HistoryLoading()) {
    on<LoadHistoryEvent>(_onLoadHistory);
    on<HistoryUpdatedEvent>(_onHistoryUpdated);
    on<ClearHistoryEvent>(_onClearHistory);

    _liveHistoryListenable = _getLiveHistoryUseCase();
    _chunkedHistoryListenable = _getChunkedHistoryUseCase();

    _liveHistoryListenable.addListener(_onLiveHistoryChanged);
    _chunkedHistoryListenable.addListener(_onChunkedHistoryChanged);

    _subscriptionStreamSub = _subscriptionDataSource.statusStream.listen((status) {
      add(HistoryUpdatedEvent(subscriptionStatus: status));
    });
  }

  void _onLoadHistory(LoadHistoryEvent event, Emitter<HistoryState> emit) {
    _currentLive = _liveHistoryListenable.value;
    _currentChunked = _chunkedHistoryListenable.value;
    _currentSubStatus = _subscriptionDataSource.currentStatus;

    emit(HistoryLoaded(
      liveEntries: _currentLive,
      chunkedEntries: _currentChunked,
      subscriptionStatus: _currentSubStatus!,
    ));
  }

  void _onHistoryUpdated(HistoryUpdatedEvent event, Emitter<HistoryState> emit) {
    if (event.liveEntries != null) {
      _currentLive = event.liveEntries!;
    }
    if (event.chunkedEntries != null) {
      _currentChunked = event.chunkedEntries!;
    }
    if (event.subscriptionStatus != null) {
      _currentSubStatus = event.subscriptionStatus!;
    }

    if (_currentSubStatus == null) return;

    emit(HistoryLoaded(
      liveEntries: _currentLive,
      chunkedEntries: _currentChunked,
      subscriptionStatus: _currentSubStatus!,
    ));
  }

  void _onClearHistory(ClearHistoryEvent event, Emitter<HistoryState> emit) {
    _clearHistoryUseCase();
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
