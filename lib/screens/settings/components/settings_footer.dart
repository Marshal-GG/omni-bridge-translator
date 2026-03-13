import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../translation/bloc/translation_bloc.dart';
import '../../translation/bloc/translation_state.dart';
import '../../translation/bloc/translation_event.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';

Widget buildSettingsFooter(BuildContext context, SettingsState state) {
  return BlocBuilder<TranslationBloc, TranslationState>(
    builder: (context, translationState) {
      final isSaving = translationState.isSettingsSaving;

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
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
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
                  onPressed: isSaving
                      ? null
                      : () {
                          context.read<SettingsBloc>().add(SaveSettingsEvent());
                          context.read<TranslationBloc>().add(
                            ApplySettingsEvent(
                              targetLang: state.settings.targetLang,
                              sourceLang: state.settings.sourceLang,
                              useMic: state.settings.useMic,
                              fontSize: state.settings.fontSize,
                              isBold: state.settings.isBold,
                              opacity: state.settings.opacity,
                              inputDeviceIndex: state.settings.inputDeviceIndex,
                              outputDeviceIndex:
                                  state.settings.outputDeviceIndex,
                              desktopVolume: state.settings.desktopVolume,
                              micVolume: state.settings.micVolume,
                              translationModel: state.settings.translationModel,
                              apiKey: state.settings.apiKey,
                              transcriptionModel:
                                  state.settings.transcriptionModel,
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black54),
                          ),
                        )
                      : const Text(
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
    },
  );
}
