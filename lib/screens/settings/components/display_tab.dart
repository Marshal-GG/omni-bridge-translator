import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import 'settings_helpers.dart';

Widget buildDisplayTab(BuildContext context, SettingsState state) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      sectionLabel('Typography'),
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
      sublabel('Font Size'),
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
      sectionLabel('Preview'),
      const SizedBox(height: 8),
      Stack(
        children: [
          // Simulated Desktop Background
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2B5876), Color(0xFF4E4376)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          // Actual Preview Content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: state.tempOpacity),
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
        ],
      ),

      const SizedBox(height: 24),
      sectionLabel('Window Opacity'),
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
                const UpdateTempSettingEvent(opacity: 0.85),
              ),
          icon: const Icon(Icons.refresh, size: 14, color: Colors.white38),
          label: const Text(
            'Reset to 85%',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
      ),
    ],
  );
}
