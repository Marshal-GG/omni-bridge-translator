import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../translation/bloc/translation_bloc.dart';
import '../translation/bloc/translation_event.dart';
import '../translation/bloc/translation_state.dart';
import '../../core/constants/languages.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranslationBloc, TranslationState>(
      builder: (context, state) {
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAudioConfiguration(context, state),
                    _buildLanguageConfiguration(context, state),
                    _buildTypographyConfiguration(context, state),
                    _buildDisplayConfiguration(context, state),
                  ],
                ),
              ),
            ),
            // STICKY SAVE/CANCEL BUTTONS
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
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.read<TranslationBloc>().add(
                        SaveSettingsEvent(),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        elevation: 4,
                      ),
                      child: const Text(
                        "Save",
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

  // --- AUDIO CONFIGURATION METHOD ---
  Widget _buildAudioConfiguration(
    BuildContext context,
    TranslationState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Audio Inputs",
          style: TextStyle(
            color: Colors.tealAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        SwitchListTile(
          title: const Text(
            "Use System Microphone",
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          subtitle: const Text(
            "Translate your own voice instead of desktop audio",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          value: state.tempUseMic,
          activeThumbColor: Colors.tealAccent,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) => context.read<TranslationBloc>().add(
            UpdateTempSettingEvent(useMic: val),
          ),
        ),
        if (state.tempUseMic) ...[
          const SizedBox(height: 15),
          const Text(
            "Input Device",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 5),
          state.devicesLoading
              ? const SizedBox(
                  height: 48,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : DropdownSearch<Map<String, dynamic>>(
                  items: state.inputDevices,
                  itemAsString: (device) => device['name'] as String,
                  selectedItem: state.tempInputDeviceIndex != null
                      ? state.inputDevices.firstWhere(
                          (d) => d['index'] == state.tempInputDeviceIndex,
                          orElse: () => {
                            'name': state.defaultInputDeviceName,
                            'index': -1,
                          },
                        )
                      : null,
                  onChanged: (device) {
                    if (device != null) {
                      context.read<TranslationBloc>().add(
                        UpdateTempSettingEvent(
                          inputDeviceIndex: device['index'] as int,
                        ),
                      );
                    } else {
                      context.read<TranslationBloc>().add(
                        const UpdateTempSettingEvent(clearInputDevice: true),
                      );
                    }
                  },
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                    menuProps: MenuProps(backgroundColor: Color(0xFF2C2C2C)),
                  ),
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      hintText: "System Default",
                      hintStyle: TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white10,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                  ),
                ),
        ] else ...[
          const SizedBox(height: 15),
          const Text(
            "Desktop Audio Output Device",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 5),
          state.devicesLoading
              ? const SizedBox(
                  height: 48,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : DropdownSearch<Map<String, dynamic>>(
                  items: state.outputDevices,
                  itemAsString: (device) => device['name'] as String,
                  selectedItem: state.tempOutputDeviceIndex != null
                      ? state.outputDevices.firstWhere(
                          (d) => d['index'] == state.tempOutputDeviceIndex,
                          orElse: () => {
                            'name': state.defaultOutputDeviceName,
                            'index': -1,
                          },
                        )
                      : null,
                  onChanged: (device) {
                    if (device != null) {
                      context.read<TranslationBloc>().add(
                        UpdateTempSettingEvent(
                          outputDeviceIndex: device['index'] as int,
                        ),
                      );
                    } else {
                      // Note: using explicit nulls with copyWith pattern in event triggers clear logic
                      context.read<TranslationBloc>().add(
                        const UpdateTempSettingEvent(clearOutputDevice: true),
                      );
                    }
                  },
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                    menuProps: MenuProps(backgroundColor: Color(0xFF2C2C2C)),
                  ),
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      hintText: "System Default",
                      hintStyle: TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white10,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                  ),
                ),
        ],
      ],
    );
  }

  // --- LANGUAGE CONFIGURATION METHOD ---
  Widget _buildLanguageConfiguration(
    BuildContext context,
    TranslationState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const Divider(color: Colors.white24),
        const SizedBox(height: 10),
        const Text(
          "Languages",
          style: TextStyle(
            color: Colors.tealAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          "Source Language (Spoken audio)",
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 5),
        DropdownSearch<MapEntry<String, String>>(
          items: appLanguages.entries.toList(),
          itemAsString: (entry) => entry.value,
          selectedItem: MapEntry(
            state.tempSourceLang,
            appLanguages[state.tempSourceLang] ?? state.tempSourceLang,
          ),
          onChanged: (entry) => context.read<TranslationBloc>().add(
            UpdateTempSettingEvent(sourceLang: entry!.key),
          ),
          popupProps: const PopupProps.menu(
            showSearchBox: true,
            menuProps: MenuProps(backgroundColor: Color(0xFF2C2C2C)),
          ),
          dropdownDecoratorProps: const DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              filled: true,
              fillColor: Colors.white10,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          "Target Language (Translation)",
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 5),
        DropdownSearch<MapEntry<String, String>>(
          items: appLanguages.entries
              .where((e) => e.key != 'auto' && e.key != 'none')
              .toList(),
          itemAsString: (entry) => entry.value,
          selectedItem: MapEntry(
            state.tempTargetLang,
            appLanguages[state.tempTargetLang] ?? state.tempTargetLang,
          ),
          onChanged: (entry) => context.read<TranslationBloc>().add(
            UpdateTempSettingEvent(targetLang: entry!.key),
          ),
          popupProps: const PopupProps.menu(
            showSearchBox: true,
            menuProps: MenuProps(backgroundColor: Color(0xFF2C2C2C)),
          ),
          dropdownDecoratorProps: const DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              filled: true,
              fillColor: Colors.white10,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- TYPOGRAPHY CONFIGURATION METHOD ---
  Widget _buildTypographyConfiguration(
    BuildContext context,
    TranslationState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 25),
        const Divider(color: Colors.white24),
        const SizedBox(height: 10),
        const Text(
          "Typography",
          style: TextStyle(
            color: Colors.tealAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        SwitchListTile(
          title: const Text(
            "Bold Text",
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          subtitle: const Text(
            "Make captions thicker and easier to read",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          value: state.tempIsBold,
          activeThumbColor: Colors.tealAccent,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) => context.read<TranslationBloc>().add(
            UpdateTempSettingEvent(isBold: val),
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          "Font Size",
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 5),
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
                onChanged: (val) => context.read<TranslationBloc>().add(
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
                    context.read<TranslationBloc>().add(
                      UpdateTempSettingEvent(fontSize: parsed),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- DISPLAY CONFIGURATION METHOD ---
  Widget _buildDisplayConfiguration(
    BuildContext context,
    TranslationState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const Divider(color: Colors.white24),
        const SizedBox(height: 10),
        const Text(
          "Display",
          style: TextStyle(
            color: Colors.tealAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          "Window Opacity",
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 5),
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
                onChanged: (val) => context.read<TranslationBloc>().add(
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
                    context.read<TranslationBloc>().add(
                      UpdateTempSettingEvent(opacity: parsed / 100.0),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => context.read<TranslationBloc>().add(
              const UpdateTempSettingEvent(opacity: 0.7),
            ),
            icon: const Icon(Icons.refresh, size: 14, color: Colors.white38),
            label: const Text(
              'Reset to 70%',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
