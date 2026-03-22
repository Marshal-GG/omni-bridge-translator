import 'package:equatable/equatable.dart';

enum UpdateStatus { idle, checking, upToDate, available, error }

class UpdateResult extends Equatable {
  final UpdateStatus status;
  final String? latestVersion;
  final String? releaseUrl;
  final String? errorMessage;

  const UpdateResult({
    required this.status,
    this.latestVersion,
    this.releaseUrl,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [status, latestVersion, releaseUrl, errorMessage];
}
