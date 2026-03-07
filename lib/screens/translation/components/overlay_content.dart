import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/translation_bloc.dart';
import '../bloc/translation_state.dart';
import '../../settings/settings_screen.dart';
import '../../settings/bloc/settings_bloc.dart';
import '../../settings/bloc/settings_state.dart';
import '../../settings/bloc/settings_event.dart';
import 'translation_header.dart';
import 'translation_content.dart';
import 'auto_detect_snackbar.dart';
import 'shrunk_caption_view.dart';

Widget buildOverlayContent(BuildContext context) {
  return BlocConsumer<TranslationBloc, TranslationState>(
    listenWhen: (prev, curr) =>
        (curr.autoDetectWarning != null &&
            prev.autoDetectWarning != curr.autoDetectWarning) ||
        prev.activeSourceLang != curr.activeSourceLang ||
        prev.activeTargetLang != curr.activeTargetLang ||
        prev.activeUseMic != curr.activeUseMic ||
        prev.activeFontSize != curr.activeFontSize ||
        prev.activeIsBold != curr.activeIsBold ||
        prev.activeOpacity != curr.activeOpacity ||
        prev.activeInputDeviceIndex != curr.activeInputDeviceIndex ||
        prev.activeOutputDeviceIndex != curr.activeOutputDeviceIndex ||
        prev.activeDesktopVolume != curr.activeDesktopVolume ||
        prev.activeMicVolume != curr.activeMicVolume ||
        prev.activeTranslationModel != curr.activeTranslationModel ||
        prev.activeApiKey != curr.activeApiKey ||
        prev.activeTranscriptionModel != curr.activeTranscriptionModel,
    listener: (context, state) {
      if (state.autoDetectWarning != null) {
        showAutoDetectWarning(context, state);
      }

      context.read<SettingsBloc>().add(
        SyncTempSettingsEvent(
          targetLang: state.activeTargetLang,
          sourceLang: state.activeSourceLang,
          useMic: state.activeUseMic,
          fontSize: state.activeFontSize,
          isBold: state.activeIsBold,
          opacity: state.activeOpacity,
          inputDeviceIndex: state.activeInputDeviceIndex,
          outputDeviceIndex: state.activeOutputDeviceIndex,
          desktopVolume: state.activeDesktopVolume,
          micVolume: state.activeMicVolume,
          translationModel: state.activeTranslationModel,
          apiKey: state.activeApiKey,
          transcriptionModel: state.activeTranscriptionModel,
        ),
      );
    },
    builder: (context, state) {
      return BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          final opacity = state.isSettingsOpen
              ? settingsState.tempOpacity
              : state.activeOpacity;

          if (state.isShrunk) {
            return buildShrunkCaptionView(context, state, opacity);
          }

          return Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: opacity),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                if (!state.isSettingsOpen) ...[
                  buildTranslationHeader(context, state),
                  const Divider(height: 1, color: Colors.white12),
                ],
                Expanded(
                  child: state.isSettingsOpen
                      ? const SettingsScreen()
                      : buildTranslationContent(context, state),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
