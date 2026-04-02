import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_bloc.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_event.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_state.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_bloc.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_event.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_state.dart';

import 'package:omni_bridge/features/settings/presentation/widgets/settings_footer.dart';
import 'package:omni_bridge/features/settings/presentation/widgets/settings_header.dart';
import 'package:omni_bridge/features/settings/presentation/widgets/input_output_tab.dart';
import 'package:omni_bridge/features/settings/presentation/widgets/languages_tab.dart';
import 'package:omni_bridge/features/settings/presentation/widgets/display_tab.dart';
import 'package:omni_bridge/core/widgets/omni_version_chip.dart';
import 'package:omni_bridge/features/shell/presentation/widgets/app_dashboard_shell.dart';
import 'package:omni_bridge/core/navigation/app_router.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/audio_level_cubit.dart';
import 'package:omni_bridge/core/di/di.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // ── Tab labels shown in the content area as a section title ──────────────
  static const _tabTitles = ['Translation', 'Display', 'Input & Output'];
  static const _tabIcons = [
    Icons.translate_rounded,
    Icons.palette_outlined,
    Icons.headphones_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final isInitialized = context.select(
      (SettingsBloc b) => b.state.isInitialized,
    );
    if (!isInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final tabIndex = args is int ? args : 0;
      final modelStatuses =
          context.read<TranslationBloc>().state.modelStatuses;

      Future.microtask(() {
        if (context.mounted) {
          context.read<SettingsBloc>().add(
            InitializeSettingsEvent(
              initialTabIndex: tabIndex,
              modelStatuses: modelStatuses,
            ),
          );
        }
      });
    }

    return BlocProvider<AudioLevelCubit>(
      create: (context) => sl<AudioLevelCubit>(),
      child: MultiBlocListener(
        listeners: [
          BlocListener<SettingsBloc, SettingsState>(
            listenWhen: (previous, current) =>
                previous.isSaving && !current.isSaving,
            listener: (context, settingsState) {
              context.read<TranslationBloc>().add(
                ApplySettingsEvent(
                  targetLang: settingsState.settings.targetLang,
                  sourceLang: settingsState.settings.sourceLang,
                  useMic: settingsState.settings.useMic,
                  fontSize: settingsState.settings.fontSize,
                  isBold: settingsState.settings.isBold,
                  opacity: settingsState.settings.opacity,
                  inputDeviceIndex: settingsState.settings.inputDeviceIndex,
                  outputDeviceIndex: settingsState.settings.outputDeviceIndex,
                  desktopVolume: settingsState.settings.desktopVolume,
                  micVolume: settingsState.settings.micVolume,
                  translationModel: settingsState.settings.translationModel,
                  nvidiaNimKey: settingsState.settings.nvidiaNimKey,
                  transcriptionModel: settingsState.settings.transcriptionModel,
                ),
              );
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
        child: BlocBuilder<SettingsBloc, SettingsState>(
          buildWhen: (prev, curr) {
            return prev.settings != curr.settings ||
                prev.isSaving != curr.isSaving ||
                prev.devicesLoading != curr.devicesLoading ||
                prev.inputDevices != curr.inputDevices ||
                prev.outputDevices != curr.outputDevices ||
                prev.activeTabIndex != curr.activeTabIndex ||
                prev.translationCompatibilityError !=
                    curr.translationCompatibilityError;
          },
          builder: (context, state) {
            return AppDashboardShell(
              currentRoute: AppRouter.settingsOverlay,
              header: buildSettingsHeader(context),
              settingsTabIndex: state.activeTabIndex,
              onSettingsTabChanged: (index) {
                context.read<SettingsBloc>().add(
                  SettingsTabIndexChanged(index),
                );
              },
              child: Container(
                color: const Color(0xFF121212),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxHeight < 200) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      children: [
                        // ── Section title bar ─────────────────────────
                        Container(
                          color: const Color(0xFF161616),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _tabIcons[state.activeTabIndex],
                                size: 15,
                                color: Colors.tealAccent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _tabTitles[state.activeTabIndex],
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.white10),

                        // ── Tab content ───────────────────────────────
                        Expanded(
                          child: BlocBuilder<TranslationBloc, TranslationState>(
                            buildWhen: (prev, curr) =>
                                prev.isSettingsLoading !=
                                curr.isSettingsLoading,
                            builder: (context, translationState) {
                              if (translationState.isSettingsLoading) {
                                return const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.tealAccent,
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'Loading settings…',
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return IndexedStack(
                                index: state.activeTabIndex,
                                children: [
                                  SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      20,
                                      20,
                                      20,
                                    ),
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 500,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            buildLanguagesTab(context, state),
                                            const SizedBox(height: 28),
                                            buildTranslationModelSelector(
                                              context,
                                              state,
                                            ),
                                            const SizedBox(height: 40),
                                            const Center(
                                              child: OmniVersionChip(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      20,
                                      20,
                                      20,
                                    ),
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 500,
                                        ),
                                        child: Column(
                                          children: [
                                            buildDisplayTab(context, state),
                                            const SizedBox(height: 40),
                                            const OmniVersionChip(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      20,
                                      20,
                                      20,
                                    ),
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 500,
                                        ),
                                        child: Column(
                                          children: [
                                            buildInputOutputTab(context, state),
                                            const SizedBox(height: 40),
                                            const OmniVersionChip(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        buildSettingsFooter(context, state),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
