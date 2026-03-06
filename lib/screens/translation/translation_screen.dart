import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import 'bloc/translation_bloc.dart';
import '../settings/bloc/settings_bloc.dart';
import '../../core/services/asr_ws_client.dart';
import 'components/overlay_content.dart';

class TranslationScreen extends StatelessWidget {
  const TranslationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => TranslationBloc(asrClient: AsrWebSocketClient()),
        ),
        BlocProvider(
          create: (context) => SettingsBloc(
            asrClient: context.read<TranslationBloc>().asrClient,
          ),
        ),
      ],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: WindowBorder(
          color: Colors.transparent,
          width: 0,
          child: Stack(
            children: [
              MoveWindow(),
              Center(child: buildOverlayContent(context)),
            ],
          ),
        ),
      ),
    );
  }
}
