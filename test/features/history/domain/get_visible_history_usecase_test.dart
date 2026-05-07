import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omni_bridge/features/history/domain/entities/history_entry.dart';
import 'package:omni_bridge/features/history/domain/usecases/get_visible_history_usecase.dart';
import 'package:omni_bridge/features/subscription/domain/repositories/i_subscription_repository.dart';

class _MockSubscription extends Mock implements ISubscriptionRepository {}

HistoryEntry _entry({
  required DateTime at,
  String text = 'hello',
}) =>
    HistoryEntry(
      transcription: text,
      translation: text,
      timestamp: at,
      sourceLang: 'en',
      targetLang: 'es',
    );

void main() {
  late _MockSubscription sub;
  late GetVisibleHistoryUseCase useCase;

  setUp(() {
    sub = _MockSubscription();
    useCase = GetVisibleHistoryUseCase(sub);
  });

  group('GetVisibleHistoryUseCase', () {
    final now = DateTime.now();
    final fresh = _entry(at: now.subtract(const Duration(hours: 1)), text: 'fresh');
    final twoDay = _entry(at: now.subtract(const Duration(days: 2)), text: 'two-day');
    final fourDay = _entry(at: now.subtract(const Duration(days: 4)), text: 'four-day');
    final entries = [fresh, twoDay, fourDay];

    test('rank 0 (free) returns empty', () {
      when(() => sub.getTierRank('free')).thenReturn(0);
      expect(useCase(entries, 'free'), isEmpty);
    });

    test('rank 1 (trial) returns all session entries', () {
      when(() => sub.getTierRank('trial')).thenReturn(1);
      expect(useCase(entries, 'trial'), entries);
    });

    test('rank 2 (pro) keeps entries from the last 3 days', () {
      when(() => sub.getTierRank('pro')).thenReturn(2);
      final visible = useCase(entries, 'pro');
      expect(visible, contains(fresh));
      expect(visible, contains(twoDay));
      expect(visible, isNot(contains(fourDay)));
    });

    test('rank 2 boundary — entry exactly 3 days old is excluded', () {
      when(() => sub.getTierRank('pro')).thenReturn(2);
      final boundary = _entry(
        at: now.subtract(const Duration(days: 3)),
        text: 'boundary',
      );
      final visible = useCase([boundary, fresh], 'pro');
      // .isAfter is strict — an entry whose timestamp equals the cutoff is dropped.
      expect(visible, [fresh]);
    });

    test('rank 3 (enterprise) returns all entries unfiltered', () {
      when(() => sub.getTierRank('enterprise')).thenReturn(3);
      expect(useCase(entries, 'enterprise'), entries);
    });

    test('rank above 3 is treated as unlimited', () {
      when(() => sub.getTierRank('platinum')).thenReturn(7);
      expect(useCase(entries, 'platinum'), entries);
    });

    test('empty input always returns empty', () {
      when(() => sub.getTierRank('pro')).thenReturn(2);
      expect(useCase(const [], 'pro'), isEmpty);
    });
  });
}
