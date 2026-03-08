import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../translation/bloc/translation_bloc.dart';
import '../../translation/bloc/translation_event.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';

Widget buildSettingsFooter(BuildContext context, SettingsState state) {
  return Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Colors.white12)),
    ),
    child: Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 42,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.05),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: () {
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

                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
