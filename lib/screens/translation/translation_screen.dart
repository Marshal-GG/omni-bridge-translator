import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import 'bloc/translation_bloc.dart';
import 'bloc/translation_event.dart';
import 'bloc/translation_state.dart';
import '../settings/settings_screen.dart';
import '../settings/bloc/settings_bloc.dart';
import '../settings/bloc/settings_state.dart';
import '../../core/services/asr_ws_client.dart';
import '../../core/services/asr_text_controller.dart';
import 'components/translation_header.dart';
import 'components/translation_content.dart';
import 'components/auto_detect_snackbar.dart';

class TranslationScreen extends StatelessWidget {
  const TranslationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => TranslationBloc(asrClient: AsrWebSocketClient()),
        ),
        BlocProvider(
          create: (context) => SettingsBloc(
            asrClient: context.read<TranslationBloc>().asrClient,
          ),
        ),
      ],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: WindowBorder(
          color: Colors.transparent,
          width: 0,
          child: Stack(
            children: [
              MoveWindow(),
              const Center(child: _OverlayContent()),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayContent extends StatelessWidget {
  const _OverlayContent();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TranslationBloc, TranslationState>(
      listenWhen: (prev, curr) =>
          curr.autoDetectWarning != null &&
          prev.autoDetectWarning != curr.autoDetectWarning,
      listener: (context, state) => showAutoDetectWarning(context, state),
      builder: (context, state) {
        return BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            final opacity = state.isSettingsOpen
                ? settingsState.tempOpacity
                : state.activeOpacity;

            if (state.isShrunk) {
              return buildShrunkView(context, state, opacity);
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: opacity),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  buildTranslationHeader(context, state),
                  const Divider(height: 1),
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
}

Widget buildShrunkView(
  BuildContext context,
  TranslationState state,
  double opacity,
) {
  return GestureDetector(
    onTap: () => context.read<TranslationBloc>().add(ToggleShrinkEvent()),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Stack(
        children: [
          MoveWindow(),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder<String>(
                valueListenable: asrTextController,
                builder: (_, text, _) => Text(
                  text.isEmpty ? 'Listening...' : text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: state.activeFontSize,
                    fontWeight: state.activeIsBold
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: Colors.white,
                    shadows: const [
                      Shadow(offset: Offset(1, 1), blurRadius: 3),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
