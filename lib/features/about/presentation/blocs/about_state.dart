import 'package:equatable/equatable.dart';
import 'package:omni_bridge/features/about/domain/entities/update_result.dart';

class AboutState extends Equatable {
  final String version;
  final UpdateStatus updateStatus;
  final UpdateResult? updateResult;

  const AboutState({
    this.version = '',
    this.updateStatus = UpdateStatus.idle,
    this.updateResult,
  });

  AboutState copyWith({
    String? version,
    UpdateStatus? updateStatus,
    UpdateResult? updateResult,
  }) {
    return AboutState(
      version: version ?? this.version,
      updateStatus: updateStatus ?? this.updateStatus,
      updateResult: updateResult ?? this.updateResult,
    );
  }

  @override
  List<Object?> get props => [version, updateStatus, updateResult];
}
