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
import 'shrunk_caption_view.dart';
import '../../subscription/upgrade_sheet.dart';

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

      // We handle the "just exceeded" visual cue via state change or specific event if needed.
      // For now, simpler: show it when isQuotaExceeded is true and it wasn't before.
      // But listener doesn't have prev. We can use a BlocListener or handle it in the BLoC.
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
                      : state.isQuotaExceeded && state.activeApiKey.isEmpty
                      ? _buildQuotaExceededView(context)
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

Widget _buildQuotaExceededView(BuildContext context) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Daily Quota Exceeded',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upgrade to Plus or Pro for more tokens, or use your own API key.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => showUpgradeSheet(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Upgrade Plan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );
}
