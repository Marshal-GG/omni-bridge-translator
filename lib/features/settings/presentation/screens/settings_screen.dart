import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_bloc.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_event.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_state.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_bloc.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_state.dart';

import 'package:omni_bridge/features/settings/presentation/widgets/settings_footer.dart';
import 'package:omni_bridge/features/settings/presentation/widgets/settings_header.dart';
import 'package:omni_bridge/features/settings/presentation/widgets/input_output_tab.dart';
import 'package:omni_bridge/features/settings/presentation/widgets/languages_tab.dart';
import 'package:omni_bridge/features/settings/presentation/widgets/display_tab.dart';
import 'package:omni_bridge/core/widgets/omni_version_chip.dart';
import 'package:omni_bridge/features/shell/presentation/widgets/app_dashboard_shell.dart';
import 'package:omni_bridge/core/navigation/app_router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _synced = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Read initial tab index from route arguments (set by nav rail sub-tab tap)
    if (!_synced) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int && args >= 0 && args < 3) {
        _tabController.index = args;
      }
    }

    if (!_synced) {
      _synced = true;
      final translationState = context.read<TranslationBloc>().state;
      if (!translationState.isSettingsLoading) {
        context.read<SettingsBloc>().add(
          SyncTempSettingsEvent(
            targetLang: translationState.activeTargetLang,
            sourceLang: translationState.activeSourceLang,
            useMic: translationState.activeUseMic,
            fontSize: translationState.activeFontSize,
            isBold: translationState.activeIsBold,
            opacity: translationState.activeOpacity,
            inputDeviceIndex: translationState.activeInputDeviceIndex,
            outputDeviceIndex: translationState.activeOutputDeviceIndex,
            desktopVolume: translationState.activeDesktopVolume,
            micVolume: translationState.activeMicVolume,
            translationModel: translationState.activeTranslationModel,
            nvidiaNimKey: translationState.activeNvidiaNimKey,
            transcriptionModel: translationState.activeTranscriptionModel,
          ),
        );
      }
      context.read<SettingsBloc>().add(LoadDevicesEvent());
    }
  }

  void _onTabChanged() {
    // Rebuild so the shell/nav rail knows which sub-tab is active.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  // ── Tab labels shown in the content area as a section title ──────────────
  static const _tabTitles = ['Translation', 'Display', 'Input & Output'];
  static const _tabIcons = [
    Icons.translate_rounded,
    Icons.palette_outlined,
    Icons.headphones_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<TranslationBloc, TranslationState>(
          listenWhen: (previous, current) =>
              previous.isSettingsLoading && !current.isSettingsLoading,
          listener: (context, translationState) {
            context.read<SettingsBloc>().add(
              SyncTempSettingsEvent(
                targetLang: translationState.activeTargetLang,
                sourceLang: translationState.activeSourceLang,
                useMic: translationState.activeUseMic,
                fontSize: translationState.activeFontSize,
                isBold: translationState.activeIsBold,
                opacity: translationState.activeOpacity,
                inputDeviceIndex: translationState.activeInputDeviceIndex,
                outputDeviceIndex: translationState.activeOutputDeviceIndex,
                desktopVolume: translationState.activeDesktopVolume,
                micVolume: translationState.activeMicVolume,
                translationModel: translationState.activeTranslationModel,
                nvidiaNimKey: translationState.activeNvidiaNimKey,
                transcriptionModel: translationState.activeTranscriptionModel,
              ),
            );
          },
        ),
        BlocListener<TranslationBloc, TranslationState>(
          listenWhen: (previous, current) =>
              previous.isSettingsSaving && !current.isSettingsSaving,
          listener: (context, translationState) {
            context.read<SettingsBloc>().add(
              SyncTempSettingsEvent(
                targetLang: translationState.activeTargetLang,
                sourceLang: translationState.activeSourceLang,
                useMic: translationState.activeUseMic,
                fontSize: translationState.activeFontSize,
                isBold: translationState.activeIsBold,
                opacity: translationState.activeOpacity,
                inputDeviceIndex: translationState.activeInputDeviceIndex,
                outputDeviceIndex: translationState.activeOutputDeviceIndex,
                desktopVolume: translationState.activeDesktopVolume,
                micVolume: translationState.activeMicVolume,
                translationModel: translationState.activeTranslationModel,
                nvidiaNimKey: translationState.activeNvidiaNimKey,
                transcriptionModel: translationState.activeTranscriptionModel,
              ),
            );

            if (mounted) {
              Navigator.pop(context);
            }
          },
        ),
      ],
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          return AppDashboardShell(
            currentRoute: AppRouter.settingsOverlay,
            header: buildSettingsHeader(context),
            settingsTabIndex: _tabController.index,
            onSettingsTabChanged: (index) =>
                _tabController.animateTo(index),
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
                                _tabIcons[_tabController.index],
                                size: 15,
                                color: Colors.tealAccent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _tabTitles[_tabController.index],
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
                              return TabBarView(
                                controller: _tabController,
                                children: [
                                  SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      20, 20, 20, 20,
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
                                      20, 20, 20, 20,
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
                                      20, 20, 20, 20,
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
    );
  }
}
