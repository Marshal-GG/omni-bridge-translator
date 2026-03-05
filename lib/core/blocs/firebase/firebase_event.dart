import 'package:equatable/equatable.dart';

abstract class FirebaseEvent extends Equatable {
  const FirebaseEvent();

  @override
  List<Object?> get props => [];
}

class InitializeFirebaseEvent extends FirebaseEvent {}
