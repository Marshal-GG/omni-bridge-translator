import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_bloc.dart';
import 'package:omni_bridge/presentation/screens/settings/bloc/settings_bloc.dart';
import 'package:omni_bridge/presentation/screens/settings/bloc/settings_event.dart';
import 'package:omni_bridge/presentation/screens/settings/bloc/settings_state.dart';
import 'package:omni_bridge/presentation/screens/settings/components/settings_helpers.dart';

Widget buildInputOutputTab(BuildContext context, SettingsState state) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: sectionLabel('Microphone Input')),
                  SizedBox(
                    height: 20, // Reduces the vertical footprint
                    child: Transform.scale(
                      scale: 0.7,
                      child: Switch(
                        value: state.settings.useMic,
                        materialTapTargetSize: MaterialTapTargetSize
                            .shrinkWrap, // Removes Flutter's forced 48px padding
                        onChanged: (val) => context.read<SettingsBloc>().add(
                          UpdateTempSettingEvent(useMic: val),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (state.settings.useMic) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: buildDeviceDropdown(
                        context: context,
                        state: state,
                        items: state.inputDevices,
                        defaultName: state.defaultInputDeviceName,
                        selectedIndex: state.settings.inputDeviceIndex,
                        hintText: 'System Default',
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
                              const UpdateTempSettingEvent(
                                clearInputDevice: true,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: VolumeSlider(
                        key: const ValueKey('Mic Volume'),
                        label: 'Volume',
                        value: state.settings.micVolume,
                        color: Colors.tealAccent,
                        onChangeEnd: (v) => context.read<SettingsBloc>().add(
                          UpdateTempSettingEvent(micVolume: v),
                        ),
                        onLiveChange: (v) => context
                            .read<TranslationBloc>()
                            .liveVolumeUpdate(
                              desktopVolume: state.settings.desktopVolume,
                              micVolume: v,
                            ),
                      ),
                    ),
                  ],
                ),
                buildDbMeter(
                  level: (state.currentInputVolume * state.settings.micVolume)
                      .clamp(0.0, 1.0),
                  label: 'Mic',
                  color: Colors.tealAccent,
                  active: true,
                ),
              ],
            ],
          ),
        ),
      ),

      const SizedBox(height: 16),

      // ── Desktop Audio section ─────────────────────────────────────────
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionLabel('Desktop Audio Output'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: buildDeviceDropdown(
                      context: context,
                      state: state,
                      items: state.outputDevices,
                      defaultName: state.defaultOutputDeviceName,
                      selectedIndex: state.settings.outputDeviceIndex,
                      hintText: 'System Default',
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
                            const UpdateTempSettingEvent(
                              clearOutputDevice: true,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: VolumeSlider(
                      key: const ValueKey('Desktop Volume'),
                      label: 'Volume',
                      value: state.settings.desktopVolume,
                      color: Colors.purpleAccent,
                      onChangeEnd: (v) => context.read<SettingsBloc>().add(
                        UpdateTempSettingEvent(desktopVolume: v),
                      ),
                      onLiveChange: (v) => context
                          .read<TranslationBloc>()
                          .liveVolumeUpdate(
                            desktopVolume: v,
                            micVolume: state.settings.micVolume,
                          ),
                    ),
                  ),
                ],
              ),
              buildDbMeter(
                level:
                    (state.currentOutputVolume * state.settings.desktopVolume)
                        .clamp(0.0, 1.0),
                label: 'Desktop',
                color: Colors.purpleAccent,
                active: true,
              ),
            ],
          ),
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
            const Icon(Icons.info_outline, size: 14, color: Colors.tealAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.settings.useMic
                    ? 'Both mic and desktop audio are active. Translation uses whichever source is louder.'
                    : 'Only desktop audio is captured. Enable mic above to also capture your voice.',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            onPressed: state.devicesLoading
                ? null
                : () =>
                      context.read<SettingsBloc>().add(ResetIODefaultsEvent()),
            icon: const Icon(Icons.restore, size: 16),
            label: const Text('Reset Defaults'),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: state.devicesLoading
                ? null
                : () => context.read<SettingsBloc>().add(LoadDevicesEvent()),
            icon: state.devicesLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  )
                : const Icon(Icons.refresh, size: 16),
            label: Text(
              state.devicesLoading
                  ? 'Refreshing Devices...'
                  : 'Refresh Devices',
            ),
          ),
        ],
      ),
    ],
  );
}

// ─── Device Dropdown ──────────────────────────────────────────────────────────

Widget buildDeviceDropdown({
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
  return SizedBox(
    height: 36,
    child: DropdownSearch<Map<String, dynamic>>(
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
        Future.delayed(const Duration(milliseconds: 100), () {
          if (context.mounted) onChanged(device);
        });
      },
      dropdownButtonProps: const DropdownButtonProps(
        padding: EdgeInsets.zero,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        mouseCursor: SystemMouseCursors.basic,
        icon: Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white38),
      ),
      popupProps: PopupProps.menu(
        showSearchBox: true,
        fit: FlexFit.loose,
        constraints: const BoxConstraints(maxHeight: 300),
        searchDelay: Duration.zero,
        searchFieldProps: TextFieldProps(
          autofocus: true,
          decoration: searchDecoration(hintText),
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
        ),
      ),
    ),
  );
}
