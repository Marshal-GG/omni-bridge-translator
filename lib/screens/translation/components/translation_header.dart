import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/translation_bloc.dart';
import '../bloc/translation_event.dart';
import '../bloc/translation_state.dart';

class TranslationHeader extends StatelessWidget {
  final TranslationState state;
  const TranslationHeader({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TranslationBloc>();
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.translate, size: 14, color: Colors.tealAccent),
          const SizedBox(width: 8),
          Text(
            state.isSettingsOpen
                ? 'Configuration'
                : 'Omni Bridge: Live AI Translator',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 15),
          IconButton(
            icon: Icon(
              state.isSettingsOpen ? Icons.close : Icons.settings,
              size: 14,
              color: Colors.white54,
            ),
            onPressed: () => bloc.add(ToggleSettingsEvent()),
          ),
          Expanded(child: MoveWindow()),
          IconButton(
            icon: const Icon(Icons.compress, size: 14, color: Colors.white70),
            onPressed: () => bloc.add(ToggleShrinkEvent()),
            tooltip: 'Shrink to Captions Only',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            splashRadius: 16,
          ),
          IconButton(
            icon: const Icon(Icons.history, size: 14, color: Colors.white70),
            onPressed: () => Navigator.pushNamed(context, '/history-panel'),
            tooltip: 'Translation History',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            splashRadius: 16,
          ),
          IconButton(
            icon: const Icon(
              Icons.manage_accounts_rounded,
              size: 14,
              color: Colors.white70,
            ),
            onPressed: () => Navigator.pushNamed(context, '/account'),
            tooltip: 'Account',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            splashRadius: 16,
          ),
          MinimizeWindowButton(
            colors: WindowButtonColors(iconNormal: Colors.white),
          ),
          CloseWindowButton(
            colors: WindowButtonColors(
              iconNormal: Colors.white,
              mouseOver: Colors.red,
            ),
            onPressed: () => appWindow.close(),
          ),
        ],
      ),
    );
  }
}
