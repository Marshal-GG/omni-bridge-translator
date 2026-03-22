import 'package:equatable/equatable.dart';

abstract class AboutEvent extends Equatable {
  const AboutEvent();

  @override
  List<Object?> get props => [];
}

class AboutInitEvent extends AboutEvent {
  const AboutInitEvent();
}

class AboutCheckUpdateEvent extends AboutEvent {
  const AboutCheckUpdateEvent();
}
