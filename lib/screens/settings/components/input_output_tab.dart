import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../translation/bloc/translation_bloc.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import 'settings_helpers.dart';

Widget buildInputOutputTab(BuildContext context, SettingsState state) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ── Microphone section ────────────────────────────────────────────
      sectionLabel('Microphone Input'),
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
        sublabel('Microphone Device'),
        const SizedBox(height: 5),
        buildDeviceDropdown(
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
        buildDbMeter(
          level: (state.currentInputVolume * state.tempMicVolume).clamp(
            0.0,
            1.0,
          ),
          label: 'Mic',
          color: Colors.tealAccent,
          active: true,
        ),
        const SizedBox(height: 8),
        VolumeSlider(
          key: const ValueKey('Mic Volume'),
          label: 'Mic Volume',
          value: state.tempMicVolume,
          color: Colors.tealAccent,
          onChangeEnd: (v) => context.read<SettingsBloc>().add(
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
          Expanded(child: sectionLabel('Desktop Audio Output')),
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
              icon: const Icon(Icons.refresh, color: Colors.white38, size: 18),
              tooltip: 'Refresh devices',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () =>
                  context.read<SettingsBloc>().add(LoadDevicesEvent()),
            ),
        ],
      ),
      const SizedBox(height: 10),
      sublabel('Output Device (loopback capture)'),
      const SizedBox(height: 5),
      buildDeviceDropdown(
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
              UpdateTempSettingEvent(outputDeviceIndex: device['index'] as int),
            );
          } else {
            context.read<SettingsBloc>().add(
              const UpdateTempSettingEvent(clearOutputDevice: true),
            );
          }
        },
      ),
      buildDbMeter(
        level: (state.currentOutputVolume * state.tempDesktopVolume).clamp(
          0.0,
          1.0,
        ),
        label: 'Desktop',
        color: Colors.purpleAccent,
        active: true,
      ),
      const SizedBox(height: 8),
      VolumeSlider(
        key: const ValueKey('Desktop Volume'),
        label: 'Desktop Volume',
        value: state.tempDesktopVolume,
        color: Colors.purpleAccent,
        onChangeEnd: (v) => context.read<SettingsBloc>().add(
          UpdateTempSettingEvent(desktopVolume: v),
        ),
        onLiveChange: (v) => context
            .read<TranslationBloc>()
            .asrClient
            .liveVolumeUpdate(desktopVolume: v, micVolume: state.tempMicVolume),
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
      Future.delayed(const Duration(milliseconds: 100), () {
        if (context.mounted) onChanged(device);
      });
    },
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    dropdownDecoratorProps: DropDownDecoratorProps(
      dropdownSearchDecoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
