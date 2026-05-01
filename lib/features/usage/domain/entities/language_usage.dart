import 'package:equatable/equatable.dart';

class LanguageUsage extends Equatable {
  final String code;
  final int tokens;
  final int calls;

  const LanguageUsage({
    required this.code,
    required this.tokens,
    required this.calls,
  });

  @override
  List<Object?> get props => [code, tokens, calls];
}
