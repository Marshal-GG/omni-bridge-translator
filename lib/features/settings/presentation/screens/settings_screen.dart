import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
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
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _version = '1.0.0';

  bool _synced = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read providers here — this is the correct lifecycle hook for accessing
    // inherited widgets. initState runs before the element is inserted into
    // the tree, so Provider.of / context.read will throw there.
    if (!_synced) {
      _synced = true;
      final translationState = context.read<TranslationBloc>().state;
      // Only sync temp settings if the TranslationBloc has already finished
      // loading settings from Firestore. If it's still loading, the
      // BlocListener below will fire a SyncTempSettingsEvent once loading
      // completes, so we don't need to do anything here and risk syncing
      // stale default values.
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
            apiKey: translationState.activeApiKey,
            transcriptionModel: translationState.activeTranscriptionModel,
          ),
        );
      }
      context.read<SettingsBloc>().add(LoadDevicesEvent());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
                apiKey: translationState.activeApiKey,
                transcriptionModel: translationState.activeTranscriptionModel,
              ),
            );
          },
        ),
        BlocListener<TranslationBloc, TranslationState>(
          listenWhen: (previous, current) =>
              previous.isSettingsSaving && !current.isSettingsSaving,
          listener: (context, translationState) {
            // After saving, sync state and close screen
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
                apiKey: translationState.activeApiKey,
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
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: WindowBorder(
              color: Colors.white12,
              width: 1,
              child: Container(
                color: const Color(0xFF121212),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Hide content while the window is transitioning to a larger size
                    // to prevent RenderFlex overflow errors during the animation.
                    if (constraints.maxHeight < 200) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      children: [
                        buildSettingsHeader(context),
                        const Divider(height: 1, color: Colors.white10),
                        Container(
                          color: const Color(0xFF1A1A1A),
                          height: 38,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 500),
                              child: TabBar(
                                controller: _tabController,
                                indicatorColor: Colors.tealAccent,
                                indicatorWeight: 2,
                                labelColor: Colors.tealAccent,
                                unselectedLabelColor: Colors.white38,
                                labelStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                ),
                                labelPadding: EdgeInsets.zero,
                                tabs: const [
                                  Tab(text: 'Translation'),
                                  Tab(text: 'Display'),
                                  Tab(text: 'Input & Output'),
                                ],
                              ),
                            ),
                          ),
                        ),
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
                                            Center(
                                              child: _VersionChip(
                                                label: 'v$_version',
                                              ),
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
                                            _VersionChip(label: 'v$_version'),
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
                                            _VersionChip(label: 'v$_version'),
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
            ),
          );
        },
      ),
    );
  }
}

class _VersionChip extends StatelessWidget {
  final String label;

  const _VersionChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        'OMNI BRIDGE $label'.toUpperCase(),
        style: const TextStyle(
          color: Colors.white24,
          fontSize: 8,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
