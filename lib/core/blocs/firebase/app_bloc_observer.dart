import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class AppBlocObserver extends BlocObserver {
  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    final eventName = event.runtimeType.toString();

    // Log to Analytics
    FirebaseAnalytics.instance.logEvent(
      name: 'bloc_event',
      parameters: {'bloc': bloc.runtimeType.toString(), 'event': eventName},
    );

    // Add to Crashlytics breadcrumbs
    FirebaseCrashlytics.instance.log(
      'Bloc Event: ${bloc.runtimeType} => $eventName',
    );
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    // Log Bloc errors to Crashlytics
    FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      reason: 'Bloc Error in ${bloc.runtimeType}',
    );
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    // Add to Crashlytics breadcrumbs
    FirebaseCrashlytics.instance.log(
      'Bloc Transition: ${bloc.runtimeType} => ${transition.currentState.runtimeType} to ${transition.nextState.runtimeType}',
    );
  }
}
