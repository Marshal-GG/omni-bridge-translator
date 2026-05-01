import 'package:equatable/equatable.dart';

enum UpdateInfoStatus { upToDate, available, forced, error }

class UpdateInfo extends Equatable {
  final UpdateInfoStatus status;
  final String? latestVersion;
  final String? releaseUrl;
  final String? downloadUrl;
  final String? errorMessage;
  final String? forceUpdateMessage;

  const UpdateInfo({
    required this.status,
    this.latestVersion,
    this.releaseUrl,
    this.downloadUrl,
    this.errorMessage,
    this.forceUpdateMessage,
  });

  @override
  List<Object?> get props => [
    status,
    latestVersion,
    releaseUrl,
    downloadUrl,
    errorMessage,
    forceUpdateMessage,
  ];
}
