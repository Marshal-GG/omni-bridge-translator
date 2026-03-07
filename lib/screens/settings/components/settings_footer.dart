import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../translation/bloc/translation_bloc.dart';
import '../../translation/bloc/translation_event.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../../../core/window_manager.dart';

Widget buildSettingsFooter(BuildContext context, SettingsState state) {
  return Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Colors.white12)),
    ),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              await setToTranslationPosition();
              if (context.mounted) {
                context.read<TranslationBloc>().add(ToggleSettingsEvent());
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              context.read<SettingsBloc>().add(SaveSettingsEvent());
              context.read<TranslationBloc>().add(
                ApplySettingsEvent(
                  targetLang: state.tempTargetLang,
                  sourceLang: state.tempSourceLang,
                  useMic: state.tempUseMic,
                  fontSize: state.tempFontSize,
                  isBold: state.tempIsBold,
                  opacity: state.tempOpacity,
                  inputDeviceIndex: state.tempInputDeviceIndex,
                  outputDeviceIndex: state.tempOutputDeviceIndex,
                  desktopVolume: state.tempDesktopVolume,
                  micVolume: state.tempMicVolume,
                  translationModel: state.tempTranslationModel,
                  apiKey: state.tempApiKey,
                  transcriptionModel: state.tempTranscriptionModel,
                ),
              );
              await setToTranslationPosition();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              elevation: 4,
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    ),
  );
}
