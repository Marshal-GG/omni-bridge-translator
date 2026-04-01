import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:omni_bridge/features/translation/presentation/blocs/translation_bloc.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_bloc.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_event.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_state.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/audio_level_cubit.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/audio_level_state.dart';
import 'package:omni_bridge/features/settings/presentation/widgets/settings_helpers.dart';
import 'package:omni_bridge/core/widgets/omni_card.dart';
import 'package:omni_bridge/core/widgets/omni_dropdown.dart';

Widget buildInputOutputTab(BuildContext context, SettingsState state) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OmniCard(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
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
                        onChanged: (val) {
                          context.read<SettingsBloc>().add(
                                UpdateTempSettingEvent(useMic: val),
                              );
                          context.read<TranslationBloc>().liveMicToggle(val);
                        },
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
                            final idx = device['index'] as int;
                            context.read<SettingsBloc>().add(
                                  UpdateTempSettingEvent(inputDeviceIndex: idx),
                                );
                            context
                                .read<TranslationBloc>()
                                .liveDeviceUpdate(inputDeviceIndex: idx);
                          } else {
                            context.read<SettingsBloc>().add(
                                  const UpdateTempSettingEvent(
                                    clearInputDevice: true,
                                  ),
                                );
                            context
                                .read<TranslationBloc>()
                                .liveDeviceUpdate(inputDeviceIndex: null);
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
                        onLiveChange: (v) =>
                            context.read<TranslationBloc>().liveVolumeUpdate(
                              desktopVolume: state.settings.desktopVolume,
                              micVolume: v,
                            ),
                      ),
                    ),
                  ],
                ),
                BlocBuilder<AudioLevelCubit, AudioLevelState>(
                  builder: (context, audioState) => buildDbMeter(
                    level: (audioState.inputLevel * state.settings.micVolume)
                        .clamp(0.0, 1.0),
                    label: 'Mic',
                    color: Colors.tealAccent,
                    active: true,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),

      const SizedBox(height: 16),

      // ── Desktop Audio section ─────────────────────────────────────────
      OmniCard(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
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
                          final idx = device['index'] as int;
                          context.read<SettingsBloc>().add(
                                UpdateTempSettingEvent(outputDeviceIndex: idx),
                              );
                          context
                              .read<TranslationBloc>()
                              .liveDeviceUpdate(outputDeviceIndex: idx);
                        } else {
                          context.read<SettingsBloc>().add(
                                const UpdateTempSettingEvent(
                                  clearOutputDevice: true,
                                ),
                              );
                          context
                              .read<TranslationBloc>()
                              .liveDeviceUpdate(outputDeviceIndex: null);
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
                      onLiveChange: (v) =>
                          context.read<TranslationBloc>().liveVolumeUpdate(
                            desktopVolume: v,
                            micVolume: state.settings.micVolume,
                          ),
                    ),
                  ),
                ],
              ),
              BlocBuilder<AudioLevelCubit, AudioLevelState>(
                builder: (context, audioState) => buildDbMeter(
                  level: (audioState.outputLevel * state.settings.desktopVolume)
                      .clamp(0.0, 1.0),
                  label: 'Desktop',
                  color: Colors.purpleAccent,
                  active: true,
                ),
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

  // Create a virtual item for the system default
  final systemDefaultItem = {
    'name': 'System Default',
    'fullName': defaultName,
    'index': null,
    'isSystem': true,
  };

  // Combine items, avoiding duplication if the specific default device is also in the list
  final List<Map<String, dynamic>> allItems = [systemDefaultItem, ...items];

  return SizedBox(
    height: 36,
    child: OmniDropdown<Map<String, dynamic>>(
      items: allItems,
      itemAsString: (device) {
        if (device['isSystem'] == true) return 'System Default';
        return device['name'] as String;
      },
      selectedItem: selectedIndex == null
          ? systemDefaultItem
          : allItems.firstWhere(
              (d) => d['index'] == selectedIndex,
              orElse: () => systemDefaultItem,
            ),
      compareFn: (a, b) =>
          a['index'] == b['index'] && a['isSystem'] == b['isSystem'],
      onChanged: (device) {
        Future.delayed(Duration.zero, () {
          if (context.mounted) {
            // If selecting system default, pass null to the backend
            if (device?['isSystem'] == true) {
              onChanged(null);
            } else {
              onChanged(device);
            }
          }
        });
      },
      itemBuilder: (context, device, isSelected) {
        final bool isSystem = device['isSystem'] == true;
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSystem
                        ? 'System Default'
                        : device['name'] as String,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.tealAccent
                          : Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                  if (isSystem)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        device['fullName'] as String,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white70
                              : Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
      hintText: hintText,
      showSearchBox: true,
    ),
  );
}
