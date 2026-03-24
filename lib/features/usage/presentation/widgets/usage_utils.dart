import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';

class UsageUtils {
  static String getDisplayName(String engineId, UsageType type) {
    final id = engineId.toLowerCase();
    if (type == UsageType.translation) {
      switch (id) {
        case 'google':
          return 'Google Translate';
        case 'google_api':
          return 'Google Cloud';
        case 'mymemory':
          return 'MyMemory';
        case 'riva':
          return 'NVIDIA Riva';
        case 'llama':
          return 'Llama 3.1 8B';
        default:
          return engineId.toUpperCase();
      }
    } else {
      // ASR (Transcription)
      if (id == 'online' || id == 'google_asr' || id == 'google-asr') {
        return 'Google ASR';
      }
      if (id == 'riva' || id == 'riva-asr' || id == 'riva_asr') {
        return 'NVIDIA Riva';
      }
      if (id.startsWith('whisper-')) {
        final size = engineId.split('-').last;
        final capitalizedSize = size.isEmpty 
            ? '' 
            : '${size[0].toUpperCase()}${size.substring(1)}';
        return 'Whisper $capitalizedSize';
      }
      return engineId.toUpperCase();
    }
  }
}
