import 'package:equatable/equatable.dart';

class SupportLink extends Equatable {
  final String title;
  final String description;
  final String url;
  final String icon;

  const SupportLink({
    required this.title,
    required this.description,
    required this.url,
    required this.icon,
  });

  @override
  List<Object?> get props => [title, description, url, icon];
}
