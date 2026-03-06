import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../../../core/constants/languages.dart';
import 'settings_helpers.dart';

Widget buildLanguagesTab(BuildContext context, SettingsState state) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      sectionLabel('Source Language'),
      const SizedBox(height: 4),
      const Text(
        'The language spoken in the captured audio',
        style: TextStyle(color: Colors.white38, fontSize: 11),
      ),
      const SizedBox(height: 10),
      _langDropdown(
        context: context,
        items: appLanguages.entries.where((e) => e.key != 'none').toList(),
        selected: MapEntry(
          state.tempSourceLang,
          appLanguages[state.tempSourceLang] ?? state.tempSourceLang,
        ),
        hint: appLanguages[state.tempSourceLang] ?? 'Search language...',
        onChanged: (entry) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (context.mounted) {
              context.read<SettingsBloc>().add(
                UpdateTempSettingEvent(sourceLang: entry!.key),
              );
            }
          });
        },
      ),
      const SizedBox(height: 20),
      const SizedBox(height: 10),
      _langDropdown(
        context: context,
        items: appLanguages.entries.where((e) => e.key != 'auto').toList(),
        selected: MapEntry(
          state.tempTargetLang,
          appLanguages[state.tempTargetLang] ?? state.tempTargetLang,
        ),
        hint: appLanguages[state.tempTargetLang] ?? 'Search language...',
        onChanged: (entry) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (context.mounted) {
              context.read<SettingsBloc>().add(
                UpdateTempSettingEvent(targetLang: entry!.key),
              );
            }
          });
        },
      ),
    ],
  );
}

Widget _langDropdown({
  required BuildContext context,
  required List<MapEntry<String, String>> items,
  required MapEntry<String, String> selected,
  required String hint,
  required ValueChanged<MapEntry<String, String>?> onChanged,
}) {
  const dropDec = DropDownDecoratorProps(
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
  );

  return DropdownSearch<MapEntry<String, String>>(
    items: items,
    itemAsString: (entry) => entry.value,
    selectedItem: selected,
    compareFn: (a, b) => a.key == b.key,
    onChanged: onChanged,
    popupProps: PopupProps.menu(
      showSearchBox: true,
      fit: FlexFit.loose,
      constraints: const BoxConstraints(maxHeight: 300),
      searchDelay: Duration.zero,
      searchFieldProps: TextFieldProps(
        autofocus: true,
        decoration: searchDecoration(hint),
      ),
      menuProps: MenuProps(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    dropdownDecoratorProps: dropDec,
  );
}

// ─── AI Engine Selector ───────────────────────────────────────────────────────

Widget buildAiEngineSelector(BuildContext context, SettingsState state) {
  const aiEngines = {
    'riva': 'NVIDIA Riva (Fast, High Quality)',
    'llama': 'Llama 3.1 8B (Accurate, Slower)',
    'google': 'Google Translate',
  };

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      sectionLabel('AI Translation Engine'),
      const SizedBox(height: 4),
      const Text(
        'Select the backend engine used to translate your speech',
        style: TextStyle(color: Colors.white38, fontSize: 11),
      ),
      const SizedBox(height: 10),
      DropdownSearch<MapEntry<String, String>>(
        items: aiEngines.entries.toList(),
        itemAsString: (entry) => entry.value,
        selectedItem: MapEntry(
          state.tempAiEngine,
          aiEngines[state.tempAiEngine] ?? state.tempAiEngine,
        ),
        compareFn: (a, b) => a.key == b.key,
        onChanged: (entry) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (context.mounted) {
              context.read<SettingsBloc>().add(
                UpdateTempSettingEvent(aiEngine: entry!.key),
              );
            }
          });
        },
        popupProps: PopupProps.menu(
          fit: FlexFit.loose,
          constraints: const BoxConstraints(maxHeight: 200),
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
