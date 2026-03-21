import 'package:omni_bridge/features/translation/domain/entities/caption_message.dart';
import 'package:omni_bridge/features/translation/domain/repositories/i_translation_repository.dart';

class ObserveCaptionsUseCase {
  final ITranslationRepository repository;

  ObserveCaptionsUseCase(this.repository);

  Stream<CaptionMessage>? call() {
    return repository.captions;
  }
}
