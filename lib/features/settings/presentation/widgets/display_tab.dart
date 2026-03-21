import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_bloc.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_event.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_state.dart';
import 'package:omni_bridge/features/settings/presentation/widgets/settings_helpers.dart';

Widget buildDisplayTab(BuildContext context, SettingsState state) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      sectionLabel('Typography'),
      const SizedBox(height: 10),
      Card(
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 4, top: 8, bottom: 8),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bold Text',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Make captions thicker and easier to read',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: state.settings.isBold,
                  onChanged: (val) => context.read<SettingsBloc>().add(
                    UpdateTempSettingEvent(isBold: val),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sublabel('Font Size'),
              const SizedBox(height: 4),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: state.settings.fontSize,
                        min: 10.0,
                        max: 48.0,
                        divisions: 38,
                        onChanged: (val) => context.read<SettingsBloc>().add(
                          UpdateTempSettingEvent(fontSize: val),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 68,
                      height: 36,
                      child: TextFormField(
                        key: ValueKey(state.settings.fontSize),
                        initialValue: state.settings.fontSize
                            .toInt()
                            .toString(),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(
                          suffixText: 'px',
                          suffixStyle: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
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
              ),
              const SizedBox(height: 12),
              sublabel('Overlay Opacity'),
              const SizedBox(height: 4),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: state.settings.opacity,
                        min: 0.1,
                        max: 1.0,
                        divisions: 18,
                        onChanged: (val) => context.read<SettingsBloc>().add(
                          UpdateTempSettingEvent(opacity: val),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 68,
                      height: 36,
                      child: TextFormField(
                        key: ValueKey(state.settings.opacity),
                        initialValue: (state.settings.opacity * 100)
                            .toInt()
                            .toString(),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(
                          suffixText: '%',
                          suffixStyle: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
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
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => context.read<SettingsBloc>().add(
                    const UpdateTempSettingEvent(opacity: 0.85, fontSize: 16.0),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text(
                    'Reset to Defaults',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // ── Live Preview ──────────────────────────────────────────────────
      const SizedBox(height: 12),
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
              color: Colors.black.withValues(alpha: state.settings.opacity),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: Colors.white,
                fontSize: state.settings.fontSize,
                fontWeight: state.settings.isBold
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
              child: const Text('The quick brown fox jumps over the lazy dog'),
            ),
          ),
        ],
      ),
    ],
  );
}
