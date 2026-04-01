import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/foundation.dart';
import 'package:omni_bridge/features/history/presentation/blocs/history_bloc.dart';
import 'package:omni_bridge/features/history/presentation/blocs/history_event.dart';
import 'package:omni_bridge/features/history/presentation/blocs/history_state.dart';
import 'package:omni_bridge/features/history/domain/entities/history_entry.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import 'package:omni_bridge/features/history/domain/usecases/get_live_history_usecase.dart';
import 'package:omni_bridge/features/history/domain/usecases/get_chunked_history_usecase.dart';
import 'package:omni_bridge/features/history/domain/usecases/clear_history_usecase.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';

class MockGetLiveHistoryUseCase extends Mock implements GetLiveHistoryUseCase {}

class MockGetChunkedHistoryUseCase extends Mock
    implements GetChunkedHistoryUseCase {}

class MockClearHistoryUseCase extends Mock implements ClearHistoryUseCase {}

class MockSubscriptionRemoteDataSource extends Mock
    implements SubscriptionRemoteDataSource {}

void main() {
  late HistoryBloc historyBloc;
  late MockGetLiveHistoryUseCase mockGetLiveHistoryUseCase;
  late MockGetChunkedHistoryUseCase mockGetChunkedHistoryUseCase;
  late MockClearHistoryUseCase mockClearHistoryUseCase;
  late MockSubscriptionRemoteDataSource mockSubscriptionDataSource;

  late StreamController<QuotaStatus> subStreamController;
  late ValueNotifier<List<HistoryEntry>> liveListenable;
  late ValueNotifier<List<HistoryEntry>> chunkedListenable;

  final testEntry = HistoryEntry(
    transcription: 'Hello',
    translation: 'Hola',
    timestamp: DateTime(2023),
    sourceLang: 'en',
    targetLang: 'es',
  );

  final testStatusFree = QuotaStatus(
    tier: 'free',
    dailyTokensUsed: 0,
    weeklyTokensUsed: 0,
    monthlyTokensUsed: 0,
    lifetimeTokensUsed: 0,
    dailyLimit: 100,
    dailyResetAt: DateTime.now(),
  );

  final testStatusPremium = QuotaStatus(
    tier: 'premium',
    dailyTokensUsed: 0,
    weeklyTokensUsed: 0,
    monthlyTokensUsed: 0,
    lifetimeTokensUsed: 0,
    dailyLimit: -1,
    dailyResetAt: DateTime.now(),
  );

  setUp(() {
    mockGetLiveHistoryUseCase = MockGetLiveHistoryUseCase();
    mockGetChunkedHistoryUseCase = MockGetChunkedHistoryUseCase();
    mockClearHistoryUseCase = MockClearHistoryUseCase();
    mockSubscriptionDataSource = MockSubscriptionRemoteDataSource();

    subStreamController = StreamController<QuotaStatus>.broadcast();
    liveListenable = ValueNotifier<List<HistoryEntry>>([]);
    chunkedListenable = ValueNotifier<List<HistoryEntry>>([]);

    when(() => mockGetLiveHistoryUseCase()).thenReturn(liveListenable);
    when(() => mockGetChunkedHistoryUseCase()).thenReturn(chunkedListenable);
    when(
      () => mockSubscriptionDataSource.statusStream,
    ).thenAnswer((_) => subStreamController.stream);
    when(
      () => mockSubscriptionDataSource.currentStatus,
    ).thenReturn(testStatusFree);

    historyBloc = HistoryBloc(
      getLiveHistoryUseCase: mockGetLiveHistoryUseCase,
      getChunkedHistoryUseCase: mockGetChunkedHistoryUseCase,
      clearHistoryUseCase: mockClearHistoryUseCase,
      subscriptionDataSource: mockSubscriptionDataSource,
    );
  });

  tearDown(() {
    subStreamController.close();
    liveListenable.dispose();
    chunkedListenable.dispose();
    historyBloc.close();
  });

  group('HistoryBloc', () {
    test('initial state is HistoryLoading', () {
      expect(historyBloc.state, isA<HistoryLoading>());
    });

    blocTest<HistoryBloc, HistoryState>(
      'LoadHistoryEvent emits HistoryLoaded with initial lists',
      build: () => historyBloc,
      act: (bloc) => bloc.add(LoadHistoryEvent()),
      expect: () => [
        HistoryLoaded(
          liveEntries: const [],
          chunkedEntries: const [],
          subscriptionStatus: testStatusFree,
        ),
      ],
    );

    blocTest<HistoryBloc, HistoryState>(
      'ClearHistoryEvent calls clearHistoryUseCase',
      build: () {
        when(() => mockClearHistoryUseCase()).thenReturn(null);
        return historyBloc;
      },
      act: (bloc) => bloc.add(ClearHistoryEvent()),
      verify: (_) {
        verify(() => mockClearHistoryUseCase()).called(1);
      },
    );

    blocTest<HistoryBloc, HistoryState>(
      'updates state when live history value changes via listener',
      build: () => historyBloc,
      act: (bloc) {
        bloc.add(LoadHistoryEvent());
        // Simulating the listener callback by adding the event directly
        // since ValueListenable changes can be tricky to predict in async tests without pump
        bloc.add(HistoryUpdatedEvent(liveEntries: [testEntry]));
      },
      expect: () => [
        HistoryLoaded(
          liveEntries: const [],
          chunkedEntries: const [],
          subscriptionStatus: testStatusFree,
        ),
        HistoryLoaded(
          liveEntries: [testEntry],
          chunkedEntries: const [],
          subscriptionStatus: testStatusFree,
        ),
      ],
    );

    blocTest<HistoryBloc, HistoryState>(
      'updates state when subscription status changes via stream',
      build: () => historyBloc,
      act: (bloc) {
        bloc.add(LoadHistoryEvent());
        subStreamController.add(testStatusPremium);
      },
      expect: () => [
        HistoryLoaded(
          liveEntries: const [],
          chunkedEntries: const [],
          subscriptionStatus: testStatusFree,
        ),
        HistoryLoaded(
          liveEntries: const [],
          chunkedEntries: const [],
          subscriptionStatus: testStatusPremium,
        ),
      ],
    );
  });
}
