import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:omni_bridge/features/about/domain/usecases/check_for_update.dart';
import 'package:omni_bridge/features/about/domain/entities/update_result.dart';
import 'package:omni_bridge/features/about/presentation/blocs/about_bloc.dart';
import 'package:omni_bridge/features/about/presentation/blocs/about_event.dart';
import 'package:omni_bridge/features/about/presentation/blocs/about_state.dart';
import 'package:omni_bridge/features/startup/presentation/notifiers/update_notifier.dart';

class MockCheckForUpdate extends Mock implements CheckForUpdate {}

void main() {
  late AboutBloc aboutBloc;
  late MockCheckForUpdate mockCheckForUpdate;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'OmniBridge',
      packageName: 'com.example.omnibridge',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: 'mock_signature',
    );
    mockCheckForUpdate = MockCheckForUpdate();
    aboutBloc = AboutBloc(checkForUpdate: mockCheckForUpdate);

    UpdateNotifier.instance.dismiss();
    UpdateNotifier.instance.latestVersion = null;
    UpdateNotifier.instance.releaseUrl = null;
  });

  tearDown(() {
    aboutBloc.close();
  });

  group('AboutBloc', () {
    test('initial state is AboutState()', () {
      expect(aboutBloc.state, const AboutState());
    });

    blocTest<AboutBloc, AboutState>(
      'emits correct state on AboutInitEvent when no update is available',
      build: () => aboutBloc,
      act: (bloc) => bloc.add(const AboutInitEvent()),
      expect: () => [
        const AboutState(
          version: '1.0.0',
          updateStatus: UpdateStatus.idle,
          updateResult: null,
        ),
      ],
    );

    blocTest<AboutBloc, AboutState>(
      'emits correct state on AboutInitEvent when update is already known available',
      build: () {
        UpdateNotifier.instance.setAvailable('2.0.0', 'http://example.com');
        return aboutBloc;
      },
      act: (bloc) => bloc.add(const AboutInitEvent()),
      expect: () => [
        const AboutState(
          version: '1.0.0',
          updateStatus: UpdateStatus.available,
          updateResult: UpdateResult(
            status: UpdateStatus.available,
            latestVersion: '2.0.0',
            releaseUrl: 'http://example.com',
          ),
        ),
      ],
    );

    blocTest<AboutBloc, AboutState>(
      'emits [checking, result] when AboutCheckUpdateEvent is added',
      build: () {
        when(() => mockCheckForUpdate()).thenAnswer(
          (_) async => const UpdateResult(
            status: UpdateStatus.available,
            latestVersion: '2.0.0',
            releaseUrl: 'http://example.com',
          ),
        );
        return aboutBloc;
      },
      act: (bloc) => bloc.add(const AboutCheckUpdateEvent()),
      expect: () => [
        const AboutState(updateStatus: UpdateStatus.checking),
        const AboutState(
          updateStatus: UpdateStatus.available,
          updateResult: UpdateResult(
            status: UpdateStatus.available,
            latestVersion: '2.0.0',
            releaseUrl: 'http://example.com',
          ),
        ),
      ],
      verify: (_) {
        expect(UpdateNotifier.instance.value, true);
        expect(UpdateNotifier.instance.latestVersion, '2.0.0');
      },
    );
  });
}
