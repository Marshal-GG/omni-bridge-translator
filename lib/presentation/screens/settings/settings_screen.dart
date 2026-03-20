import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:omni_bridge/presentation/screens/settings/bloc/settings_bloc.dart';
import 'package:omni_bridge/presentation/screens/settings/bloc/settings_event.dart';
import 'package:omni_bridge/presentation/screens/settings/bloc/settings_state.dart';
import 'package:omni_bridge/presentation/screens/translation/bloc/translation_bloc.dart';
import 'package:omni_bridge/presentation/screens/translation/bloc/translation_state.dart';


import 'package:omni_bridge/presentation/screens/settings/components/settings_footer.dart';
import 'package:omni_bridge/presentation/screens/settings/components/settings_header.dart';
import 'package:omni_bridge/presentation/screens/settings/components/input_output_tab.dart';
import 'package:omni_bridge/presentation/screens/settings/components/languages_tab.dart';
import 'package:omni_bridge/presentation/screens/settings/components/display_tab.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Sync current active settings to temporary state
    final translationState = context.read<TranslationBloc>().state;
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

    context.read<SettingsBloc>().add(LoadDevicesEvent());
    
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
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
                    transcriptionModel:
                        translationState.activeTranscriptionModel,
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
                    transcriptionModel:
                        translationState.activeTranscriptionModel,
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
                            child: SizedBox(
                              width: 500,
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
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              SingleChildScrollView(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 20, 20, 20),
                                child: Center(
                                  child: SizedBox(
                                    width: 500,
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
                                padding:
                                    const EdgeInsets.fromLTRB(20, 20, 20, 20),
                                child: Center(
                                  child: SizedBox(
                                    width: 500,
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
                                padding:
                                    const EdgeInsets.fromLTRB(20, 20, 20, 20),
                                child: Center(
                                  child: SizedBox(
                                    width: 500,
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
