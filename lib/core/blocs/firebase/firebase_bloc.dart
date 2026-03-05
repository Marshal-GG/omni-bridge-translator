import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../firebase_options.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_event.dart';
import 'firebase_state.dart';

class FirebaseBloc extends Bloc<FirebaseEvent, FirebaseState> {
  // If Firestore is needed, it can be instantiated here later
  // final FirebaseFirestore firestore = FirebaseFirestore.instance;

  FirebaseBloc() : super(FirebaseState.initial()) {
    on<InitializeFirebaseEvent>(_onInitialize);
  }

  Future<void> _onInitialize(
    InitializeFirebaseEvent event,
    Emitter<FirebaseState> emit,
  ) async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      emit(state.copyWith(isInitialized: true, hasError: false));
    } catch (e) {
      emit(
        state.copyWith(
          isInitialized: false,
          hasError: true,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
