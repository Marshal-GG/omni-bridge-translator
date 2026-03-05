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

class TranslationScreen extends StatelessWidget {
  const TranslationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Provide the Bloc at the top of the Translation Screen tree
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => TranslationBloc(asrClient: AsrWebSocketClient()),
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
              const Center(child: DraggableOverlayContent()),
            ],
          ),
        ),
      ),
    );
  }
}

class DraggableOverlayContent extends StatelessWidget {
  const DraggableOverlayContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TranslationBloc, TranslationState>(
      listenWhen: (prev, curr) =>
          curr.autoDetectWarning != null &&
          prev.autoDetectWarning != curr.autoDetectWarning,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2A1A1A),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 10),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orangeAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Language Error',
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  state.autoDetectWarning!,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => messenger.hideCurrentSnackBar(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white38,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Dismiss',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        messenger.hideCurrentSnackBar();
                        context.read<TranslationBloc>().add(
                          ToggleSettingsEvent(),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.tealAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Open Settings',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      builder: (context, state) {
        return BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            if (state.isShrunk) {
              return GestureDetector(
                onTap: () =>
                    context.read<TranslationBloc>().add(ToggleShrinkEvent()),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: state.isSettingsOpen
                          ? settingsState.tempOpacity
                          : state.activeOpacity,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Stack(
                    children: [
                      MoveWindow(),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: ValueListenableBuilder<String>(
                            valueListenable: asrTextController,
                            builder: (_, text, _) => Text(
                              text.isEmpty ? "Listening..." : text,
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

            return Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(
                  alpha: state.isSettingsOpen
                      ? settingsState.tempOpacity
                      : state.activeOpacity,
                ),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  _buildTranslationHeader(context, state),
                  const Divider(height: 1),
                  Expanded(
                    child: state.isSettingsOpen
                        ? const SettingsScreen()
                        : _buildTranslationContent(context, state),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- HEADER CONFIGURATION METHOD ---
  Widget _buildTranslationHeader(BuildContext context, TranslationState state) {
    final bloc = context.read<TranslationBloc>();
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.translate, size: 14, color: Colors.tealAccent),
          const SizedBox(width: 8),
          Text(
            state.isSettingsOpen
                ? "Configuration"
                : "Omni Bridge: Live AI Translator",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 15),
          IconButton(
            icon: Icon(
              state.isSettingsOpen ? Icons.close : Icons.settings,
              size: 14,
              color: Colors.white54,
            ),
            onPressed: () => bloc.add(ToggleSettingsEvent()),
          ),
          Expanded(child: MoveWindow()),
          IconButton(
            icon: const Icon(Icons.compress, size: 14, color: Colors.white70),
            onPressed: () => bloc.add(ToggleShrinkEvent()),
            tooltip: 'Shrink to Captions Only',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            splashRadius: 16,
          ),
          IconButton(
            icon: const Icon(Icons.history, size: 14, color: Colors.white70),
            onPressed: () => Navigator.pushNamed(context, '/history-panel'),
            tooltip: 'Translation History',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            splashRadius: 16,
          ),
          IconButton(
            icon: const Icon(
              Icons.manage_accounts_rounded,
              size: 14,
              color: Colors.white70,
            ),
            onPressed: () => Navigator.pushNamed(context, '/account'),
            tooltip: 'Account',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            splashRadius: 16,
          ),
          MinimizeWindowButton(
            colors: WindowButtonColors(iconNormal: Colors.white),
          ),
          CloseWindowButton(
            colors: WindowButtonColors(
              iconNormal: Colors.white,
              mouseOver: Colors.red,
            ),
            onPressed: () => appWindow.close(),
          ),
        ],
      ),
    );
  }

  // --- CONTENT CONFIGURATION METHOD ---
  Widget _buildTranslationContent(
    BuildContext context,
    TranslationState state,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ValueListenableBuilder<String>(
        valueListenable: asrTextController,
        builder: (_, text, _) {
          return Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: state.activeFontSize,
              fontWeight: state.activeIsBold
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }
}
