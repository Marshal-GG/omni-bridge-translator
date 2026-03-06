import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../translation/bloc/translation_bloc.dart';
import '../../translation/bloc/translation_event.dart';
import '../../../core/window_manager.dart';

class SettingsHeader extends StatelessWidget {
  const SettingsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.settings_rounded, size: 14, color: Colors.white38),
          const SizedBox(width: 8),
          const Text(
            'Settings',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(child: MoveWindow()),
          MinimizeWindowButton(
            colors: WindowButtonColors(iconNormal: Colors.white38),
          ),
          CloseWindowButton(
            colors: WindowButtonColors(
              iconNormal: Colors.white38,
              mouseOver: Colors.redAccent,
            ),
            onPressed: () async {
              await setToTranslationPosition();
              if (context.mounted) {
                context.read<TranslationBloc>().add(ToggleSettingsEvent());
              }
            },
          ),
        ],
      ),
    );
  }
}
