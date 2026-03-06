import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../translation/bloc/translation_bloc.dart';
import '../translation/bloc/translation_event.dart';
import 'bloc/settings_bloc.dart';
import 'bloc/settings_event.dart';
import 'bloc/settings_state.dart';
import '../../core/constants/languages.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Sync current TranslationBloc state into SettingsBloc and load devices
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final transState = context.read<TranslationBloc>().state;
        context.read<SettingsBloc>().add(
          SyncTempSettingsEvent(
            targetLang: transState.activeTargetLang,
            sourceLang: transState.activeSourceLang,
            useMic: transState.activeUseMic,
            fontSize: transState.activeFontSize,
            isBold: transState.activeIsBold,
            opacity: transState.activeOpacity,
            inputDeviceIndex: transState.activeInputDeviceIndex,
            outputDeviceIndex: transState.activeOutputDeviceIndex,
            desktopVolume: transState.activeDesktopVolume,
            micVolume: transState.activeMicVolume,
          ),
        );
        context.read<SettingsBloc>().add(LoadDevicesEvent());
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return Column(
          children: [
            // ── Tab bar ───────────────────────────────────────────────────
            Container(
              color: const Color(0xFF1A1A1A),
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.tealAccent,
                indicatorWeight: 2,
                labelColor: Colors.tealAccent,
                unselectedLabelColor: Colors.white38,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Input & Output'),
                  Tab(text: 'Languages'),
                  Tab(text: 'Display'),
                ],
              ),
            ),

            // ── Tab content ───────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTabContent(_buildInputOutputTab(context, state)),
                  _buildTabContent(_buildLanguagesTab(context, state)),
                  _buildTabContent(_buildDisplayTab(context, state)),
                ],
              ),
            ),

            // ── Sticky Save / Cancel ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.read<TranslationBloc>().add(
                        ToggleSettingsEvent(),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        context.read<SettingsBloc>().add(SaveSettingsEvent());
                        // Apply the saved settings in TranslationBloc via a callback (which we might handle soon) or another event
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
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        elevation: 4,
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabContent(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: child,
    );
  }

  // ─── INPUT & OUTPUT TAB ─────────────────────────────────────────────────────

  Widget _buildInputOutputTab(BuildContext context, SettingsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Microphone section ────────────────────────────────────────────
        _sectionLabel('Microphone Input'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: SwitchListTile(
            title: const Text(
              'Enable Microphone',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            subtitle: const Text(
              'Capture audio from your microphone',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
            value: state.tempUseMic,
            activeThumbColor: Colors.tealAccent,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 2,
            ),
            dense: true,
            onChanged: (val) => context.read<SettingsBloc>().add(
              UpdateTempSettingEvent(useMic: val),
            ),
          ),
        ),
        if (state.tempUseMic) ...[
          const SizedBox(height: 10),
          _sublabel('Microphone Device'),
          const SizedBox(height: 5),
          _deviceDropdown(
            context: context,
            state: state,
            items: state.inputDevices,
            defaultName: state.defaultInputDeviceName,
            selectedIndex: state.tempInputDeviceIndex,
            hintText: 'System Default (${state.defaultInputDeviceName})',
            loading: state.devicesLoading,
            onChanged: (device) {
              if (device != null) {
                context.read<SettingsBloc>().add(
                  UpdateTempSettingEvent(
                    inputDeviceIndex: device['index'] as int,
                  ),
                );
              } else {
                context.read<SettingsBloc>().add(
                  const UpdateTempSettingEvent(clearInputDevice: true),
                );
              }
            },
          ),
          _buildDbMeter(
            level: (state.currentInputVolume * state.tempMicVolume).clamp(
              0.0,
              1.0,
            ),
            label: 'Mic',
            color: Colors.tealAccent,
            active: true,
          ),
          const SizedBox(height: 8),
          _buildVolumeSlider(
            context: context,
            label: 'Mic Volume',
            value: state.tempMicVolume,
            color: Colors.tealAccent,
            onChanged: (v) => context.read<SettingsBloc>().add(
              UpdateTempSettingEvent(micVolume: v),
            ),
            onLiveChange: (v) =>
                context.read<TranslationBloc>().asrClient.liveVolumeUpdate(
                  desktopVolume: state.tempDesktopVolume,
                  micVolume: v,
                ),
          ),
        ],

        const SizedBox(height: 20),

        // ── Desktop Audio section ─────────────────────────────────────────
        Row(
          children: [
            Expanded(child: _sectionLabel('Desktop Audio Output')),
            if (state.devicesLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.tealAccent,
                ),
              )
            else
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.white38,
                  size: 18,
                ),
                tooltip: 'Refresh devices',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () =>
                    context.read<SettingsBloc>().add(LoadDevicesEvent()),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _sublabel('Output Device (loopback capture)'),
        const SizedBox(height: 5),
        _deviceDropdown(
          context: context,
          state: state,
          items: state.outputDevices,
          defaultName: state.defaultOutputDeviceName,
          selectedIndex: state.tempOutputDeviceIndex,
          hintText: 'System Default (${state.defaultOutputDeviceName})',
          loading: state.devicesLoading,
          onChanged: (device) {
            if (device != null) {
              context.read<SettingsBloc>().add(
                UpdateTempSettingEvent(
                  outputDeviceIndex: device['index'] as int,
                ),
              );
            } else {
              context.read<SettingsBloc>().add(
                const UpdateTempSettingEvent(clearOutputDevice: true),
              );
            }
          },
        ),
        _buildDbMeter(
          level: (state.currentOutputVolume * state.tempDesktopVolume).clamp(
            0.0,
            1.0,
          ),
          label: 'Desktop',
          color: Colors.purpleAccent,
          active: true,
        ),
        const SizedBox(height: 8),
        _buildVolumeSlider(
          context: context,
          label: 'Desktop Volume',
          value: state.tempDesktopVolume,
          color: Colors.purpleAccent,
          onChanged: (v) => context.read<SettingsBloc>().add(
            UpdateTempSettingEvent(desktopVolume: v),
          ),
          onLiveChange: (v) =>
              context.read<TranslationBloc>().asrClient.liveVolumeUpdate(
                desktopVolume: v,
                micVolume: state.tempMicVolume,
              ),
        ),

        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.tealAccent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 14,
                color: Colors.tealAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.tempUseMic
                      ? 'Both mic and desktop audio are active. Translation uses whichever source is louder.'
                      : 'Only desktop audio is captured. Enable mic above to also capture your voice.',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── LANGUAGES TAB ──────────────────────────────────────────────────────────

  Widget _buildLanguagesTab(BuildContext context, SettingsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Source Language'),
        const SizedBox(height: 4),
        Text(
          'The language spoken in the captured audio',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 10),
        DropdownSearch<MapEntry<String, String>>(
          items: appLanguages.entries
              .where((e) => e.key != 'none') // 'none' belongs on target
              .toList(),
          itemAsString: (entry) => entry.value,
          selectedItem: MapEntry(
            state.tempSourceLang,
            appLanguages[state.tempSourceLang] ?? state.tempSourceLang,
          ),
          compareFn: (item, selectedItem) => item.key == selectedItem.key,
          onChanged: (entry) {
            // Delay updating bloc so DropdownSearch finishes closing without unmounting mid-frame
            Future.delayed(const Duration(milliseconds: 100), () {
              if (context.mounted) {
                context.read<SettingsBloc>().add(
                  UpdateTempSettingEvent(sourceLang: entry!.key),
                );
              }
            });
          },
          popupProps: PopupProps.menu(
            showSearchBox: true,
            fit: FlexFit.loose,
            constraints: const BoxConstraints(maxHeight: 300),
            searchDelay: Duration.zero,
            searchFieldProps: TextFieldProps(
              autofocus: true,
              decoration: _searchDecoration(
                appLanguages[state.tempSourceLang] ?? 'Search language...',
              ),
            ),
            menuProps: MenuProps(
              backgroundColor: const Color(0xFF2C2C2C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          dropdownDecoratorProps: const DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              filled: true,
              fillColor: Colors.white10,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Colors.white24),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _sectionLabel('Target Language'),
        const SizedBox(height: 4),
        Text(
          'The language to translate captions into',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 10),
        DropdownSearch<MapEntry<String, String>>(
          items: appLanguages.entries
              .where((e) => e.key != 'auto') // include 'none' = Original Source
              .toList(),
          itemAsString: (entry) => entry.value,
          selectedItem: MapEntry(
            state.tempTargetLang,
            appLanguages[state.tempTargetLang] ?? state.tempTargetLang,
          ),
          compareFn: (item, selectedItem) => item.key == selectedItem.key,
          onChanged: (entry) {
            // Delay updating bloc so DropdownSearch finishes closing without unmounting mid-frame
            Future.delayed(const Duration(milliseconds: 100), () {
              if (context.mounted) {
                context.read<SettingsBloc>().add(
                  UpdateTempSettingEvent(targetLang: entry!.key),
                );
              }
            });
          },
          popupProps: PopupProps.menu(
            showSearchBox: true,
            fit: FlexFit.loose,
            constraints: const BoxConstraints(maxHeight: 300),
            searchDelay: Duration.zero,
            searchFieldProps: TextFieldProps(
              autofocus: true,
              decoration: _searchDecoration(
                appLanguages[state.tempTargetLang] ?? 'Search language...',
              ),
            ),
            menuProps: MenuProps(
              backgroundColor: const Color(0xFF2C2C2C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          dropdownDecoratorProps: const DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              filled: true,
              fillColor: Colors.white10,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Colors.white24),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── DISPLAY TAB ────────────────────────────────────────────────────────────

  Widget _buildDisplayTab(BuildContext context, SettingsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Typography'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: SwitchListTile(
            title: const Text(
              'Bold Text',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            subtitle: const Text(
              'Make captions thicker and easier to read',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
            value: state.tempIsBold,
            activeThumbColor: Colors.tealAccent,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 2,
            ),
            dense: true,
            onChanged: (val) => context.read<SettingsBloc>().add(
              UpdateTempSettingEvent(isBold: val),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _sublabel('Font Size'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: state.tempFontSize,
                min: 10.0,
                max: 48.0,
                divisions: 38,
                activeColor: Colors.tealAccent,
                inactiveColor: Colors.white24,
                onChanged: (val) => context.read<SettingsBloc>().add(
                  UpdateTempSettingEvent(fontSize: val),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 60,
              child: TextFormField(
                key: ValueKey(state.tempFontSize),
                initialValue: state.tempFontSize.toInt().toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.tealAccent),
                  ),
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null && parsed >= 10 && parsed <= 48) {
                    context.read<SettingsBloc>().add(
                      UpdateTempSettingEvent(fontSize: parsed),
                    );
                  }
                },
              ),
            ),
          ],
        ),

        // ── Live Preview ──────────────────────────────────────────────────
        const SizedBox(height: 20),
        _sectionLabel('Preview'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: Colors.white,
              fontSize: state.tempFontSize,
              fontWeight: state.tempIsBold
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
            child: const Text('The quick brown fox jumps over the lazy dog'),
          ),
        ),

        const SizedBox(height: 24),
        _sectionLabel('Window Opacity'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: state.tempOpacity,
                min: 0.1,
                max: 1.0,
                divisions: 18,
                activeColor: Colors.tealAccent,
                inactiveColor: Colors.white24,
                onChanged: (val) => context.read<SettingsBloc>().add(
                  UpdateTempSettingEvent(opacity: val),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 60,
              child: TextFormField(
                key: ValueKey(state.tempOpacity),
                initialValue: (state.tempOpacity * 100).toInt().toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  isDense: true,
                  suffix: Text(
                    '%',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.tealAccent),
                  ),
                ),
                onChanged: (val) {
                  final parsed = int.tryParse(val);
                  if (parsed != null && parsed >= 10 && parsed <= 100) {
                    context.read<SettingsBloc>().add(
                      UpdateTempSettingEvent(opacity: parsed / 100.0),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => context.read<SettingsBloc>().add(
              const UpdateTempSettingEvent(opacity: 0.7),
            ),
            icon: const Icon(Icons.refresh, size: 14, color: Colors.white38),
            label: const Text(
              'Reset to 70%',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  // ─── SHARED HELPERS ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.tealAccent,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    );
  }

  Widget _sublabel(String text) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white70, fontSize: 12),
    );
  }

  InputDecoration _searchDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
      filled: true,
      fillColor: Colors.black26,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _deviceDropdown({
    required BuildContext context,
    required SettingsState state,
    required List<Map<String, dynamic>> items,
    required String defaultName,
    required int? selectedIndex,
    required String hintText,
    required bool loading,
    required void Function(Map<String, dynamic>?) onChanged,
  }) {
    if (loading) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return DropdownSearch<Map<String, dynamic>>(
      items: items,
      itemAsString: (device) => device['name'] == defaultName
          ? '${device['name']} (Default)'
          : device['name'] as String,
      selectedItem: selectedIndex != null
          ? items.firstWhere(
              (d) => d['index'] == selectedIndex,
              orElse: () => {'name': defaultName, 'index': -1},
            )
          : null,
      compareFn: (item, selectedItem) => item['index'] == selectedItem['index'],
      onChanged: (device) {
        // Delay updating bloc so DropdownSearch finishes closing without unmounting mid-frame
        Future.delayed(const Duration(milliseconds: 100), () {
          if (context.mounted) {
            onChanged(device);
          }
        });
      },
      popupProps: PopupProps.menu(
        showSearchBox: true,
        fit: FlexFit.loose,
        constraints: const BoxConstraints(maxHeight: 300),
        searchDelay: Duration.zero,
        searchFieldProps: TextFieldProps(
          autofocus: true,
          decoration: _searchDecoration(hintText),
        ),
        menuProps: MenuProps(
          backgroundColor: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.white10,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          // Remove default Material border highlight
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Colors.white12),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Colors.white12),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Colors.white24),
          ),
        ),
      ),
    );
  }

  Widget _buildDbMeter({
    required double level,
    required String label,
    required Color color,
    required bool active,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.graphic_eq,
                size: 12,
                color: active ? color : Colors.white24,
              ),
              const SizedBox(width: 4),
              Text(
                '$label Level',
                style: TextStyle(
                  color: active ? Colors.white54 : Colors.white24,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 6,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    curve: Curves.easeOut,
                    height: 6,
                    width: constraints.maxWidth * level.clamp(0.0, 1.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: level > 0.9
                            ? [Colors.redAccent, Colors.red]
                            : level > 0.6
                            ? [color, Colors.yellowAccent]
                            : [color.withValues(alpha: 0.7), color],
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: active && level > 0.02
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeSlider({
    required BuildContext context,
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onLiveChange,
  }) {
    return _VolumeSlider(
      key: ValueKey(label), // stable key — widget is updated not recreated
      label: label,
      value: value,
      color: color,
      onChangeEnd: onChanged,
      onLiveChange: onLiveChange,
    );
  }
}

// ─── Volume Slider ─────────────────────────────────────────────────────────────
// Self-contained StatefulWidget so local drag state is isolated from BlocBuilder.
// The percentage label updates live on every frame; bloc events fire only on release.

class _VolumeSlider extends StatefulWidget {
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChangeEnd;
  final ValueChanged<double>? onLiveChange;

  const _VolumeSlider({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.onChangeEnd,
    this.onLiveChange,
  });

  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  late double _localValue;

  @override
  void initState() {
    super.initState();
    _localValue = widget.value;
  }

  @override
  void didUpdateWidget(_VolumeSlider old) {
    super.didUpdateWidget(old);
    // Only sync from bloc if the user isn't actively dragging
    if (old.value != widget.value) {
      _localValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_localValue * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volume_up_rounded, size: 12, color: widget.color),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
              const Spacer(),
              Text(
                '$pct%',
                style: TextStyle(
                  color: widget.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: widget.color,
              inactiveTrackColor: Colors.white12,
              thumbColor: widget.color,
              overlayColor: widget.color.withValues(alpha: 0.15),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: _localValue.clamp(0.0, 2.0),
              min: 0.0,
              max: 2.0,
              divisions: 40,
              // onChanged: update local display + send live to server; no bloc rebuild
              onChanged: (v) {
                setState(() => _localValue = v);
                widget.onLiveChange?.call(v);
              },
              // onChangeEnd: dispatch to bloc only once when user lifts finger
              onChangeEnd: widget.onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}
