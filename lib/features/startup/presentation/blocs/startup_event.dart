import 'package:equatable/equatable.dart';

abstract class StartupEvent extends Equatable {
  const StartupEvent();

  @override
  List<Object?> get props => [];
}

class StartupInitializeEvent extends StartupEvent {
  const StartupInitializeEvent();
}
