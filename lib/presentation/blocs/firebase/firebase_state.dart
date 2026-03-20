import 'package:equatable/equatable.dart';

class FirebaseState extends Equatable {
  final bool isInitialized;
  final bool hasError;
  final String? errorMessage;

  const FirebaseState({
    this.isInitialized = false,
    this.hasError = false,
    this.errorMessage,
  });

  factory FirebaseState.initial() => const FirebaseState();

  FirebaseState copyWith({
    bool? isInitialized,
    bool? hasError,
    String? errorMessage,
  }) {
    return FirebaseState(
      isInitialized: isInitialized ?? this.isInitialized,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [isInitialized, hasError, errorMessage];
}
