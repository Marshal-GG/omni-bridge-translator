import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:omni_bridge/features/subscription/domain/entities/subscription_plan.dart';
import 'package:omni_bridge/features/subscription/domain/entities/subscription_status.dart';
import 'package:omni_bridge/features/subscription/domain/repositories/i_subscription_repository.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/activate_trial.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/get_available_plans.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/get_subscription_status.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/has_used_trial.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/open_checkout.dart';
import 'package:omni_bridge/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:omni_bridge/features/subscription/presentation/bloc/subscription_event.dart';
import 'package:omni_bridge/features/subscription/presentation/bloc/subscription_state.dart';

class MockSubscriptionRepository extends Mock
    implements ISubscriptionRepository {}

class MockGetSubscriptionStatus extends Mock implements GetSubscriptionStatus {}

class MockGetAvailablePlans extends Mock implements GetAvailablePlans {}

class MockActivateTrial extends Mock implements ActivateTrial {}

class MockOpenCheckout extends Mock implements OpenCheckout {}

class MockHasUsedTrial extends Mock implements HasUsedTrial {}

// Use a const plan so it is identical by reference in both test and bloc
const _fakePlan = SubscriptionPlan(
  id: 'free',
  name: 'Free Plan',
  price: '\$0',
  description: 'Basic access',
  features: ['Feature 1'],
);

final _fakeStatus = SubscriptionStatus(
  tier: 'free',
  dailyTokensUsed: 10,
  weeklyTokensUsed: 50,
  monthlyTokensUsed: 100,
  lifetimeTokensUsed: 500,
  dailyLimit: 1000,
  dailyResetAt: DateTime(2026, 1, 1),
);

void main() {
  late MockGetSubscriptionStatus mockGetStatus;
  late MockGetAvailablePlans mockGetPlans;
  late MockActivateTrial mockActivateTrial;
  late MockOpenCheckout mockOpenCheckout;
  late MockHasUsedTrial mockHasUsedTrial;

  late StreamController<SubscriptionStatus> statusController;
  late StreamController<void> configController;

  setUp(() {
    mockGetStatus = MockGetSubscriptionStatus();
    mockGetPlans = MockGetAvailablePlans();
    mockActivateTrial = MockActivateTrial();
    mockOpenCheckout = MockOpenCheckout();
    mockHasUsedTrial = MockHasUsedTrial();
    statusController = StreamController<SubscriptionStatus>.broadcast();
    configController = StreamController<void>.broadcast();

    when(() => mockGetStatus()).thenAnswer((_) => statusController.stream);
    when(() => mockGetStatus.current).thenReturn(null);
    when(() => mockGetPlans()).thenReturn(const [_fakePlan]);
    when(() => mockGetPlans.onChange).thenAnswer((_) => configController.stream);
    when(() => mockHasUsedTrial()).thenAnswer((_) async => false);
  });

  tearDown(() {
    statusController.close();
    configController.close();
  });

  SubscriptionBloc buildBloc() => SubscriptionBloc(
        getStatus: mockGetStatus,
        getPlans: mockGetPlans,
        activateTrial: mockActivateTrial,
        openCheckout: mockOpenCheckout,
        hasUsedTrial: mockHasUsedTrial,
      );

  test('initial state has isLoading true', () {
    final bloc = buildBloc();
    expect(bloc.state.isLoading, isTrue);
    bloc.close();
  });

  blocTest<SubscriptionBloc, SubscriptionState>(
    'emits loaded state after auto SubscriptionLoaded dispatched in constructor',
    build: buildBloc,
    wait: const Duration(milliseconds: 50),
    verify: (bloc) {
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.trialUsed, isFalse);
      expect(bloc.state.plans.length, 1);
      expect(bloc.state.plans.first.id, 'free');
    },
  );

  blocTest<SubscriptionBloc, SubscriptionState>(
    'emits updated state with status when stream fires',
    build: buildBloc,
    act: (bloc) {
      Future.delayed(const Duration(milliseconds: 50), () {
        statusController.add(_fakeStatus);
      });
    },
    wait: const Duration(milliseconds: 200),
    verify: (bloc) {
      expect(bloc.state.status?.tier, 'free');
      expect(bloc.state.isLoading, isFalse);
    },
  );

  blocTest<SubscriptionBloc, SubscriptionState>(
    'emits error state when activateTrial fails',
    setUp: () {
      when(() => mockActivateTrial()).thenAnswer((_) async => 'Trial error');
    },
    build: buildBloc,
    act: (bloc) async {
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(SubscriptionActivateTrial());
    },
    wait: const Duration(milliseconds: 200),
    verify: (bloc) {
      expect(bloc.state.error, 'Trial error');
      expect(bloc.state.isLoading, isFalse);
    },
  );

  blocTest<SubscriptionBloc, SubscriptionState>(
    'emits trialUsed=true when activateTrial succeeds',
    setUp: () {
      when(() => mockActivateTrial()).thenAnswer((_) async => null);
      when(() => mockHasUsedTrial()).thenAnswer((_) async => true);
    },
    build: buildBloc,
    act: (bloc) async {
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(SubscriptionActivateTrial());
    },
    wait: const Duration(milliseconds: 200),
    verify: (bloc) {
      expect(bloc.state.trialUsed, isTrue);
      expect(bloc.state.isLoading, isFalse);
    },
  );
}
