import 'package:equatable/equatable.dart';

abstract class StartupState extends Equatable {
  const StartupState();

  @override
  List<Object?> get props => [];
}

class StartupInitial extends StartupState {
  const StartupInitial();
}

class StartupLoading extends StartupState {
  const StartupLoading();
}

class StartupProgress extends StartupState {
  final String message;
  final double progress;

  const StartupProgress(this.message, this.progress);

  @override
  List<Object?> get props => [message, progress];
}

class StartupNavigateToHome extends StartupState {
  const StartupNavigateToHome();
}

class StartupNavigateToOnboarding extends StartupState {
  const StartupNavigateToOnboarding();
}

class StartupNavigateToForceUpdate extends StartupState {
  const StartupNavigateToForceUpdate();
}

class StartupFailure extends StartupState {
  final String message;

  const StartupFailure(this.message);

  @override
  List<Object?> get props => [message];
}
