import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_bloc.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_event.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_state.dart';
import 'package:omni_bridge/core/device/asr_text_controller.dart';

Widget buildTranslationContent(BuildContext context, TranslationState state) {
  return Container(
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.all(16),
    child: ValueListenableBuilder<String>(
      valueListenable: asrTextController,
      builder: (context, text, _) {
        final bloc = context.read<TranslationBloc>();

        // Ask bloc to measure line count and potentially trim
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final width = MediaQuery.sizeOf(context).width;
          bloc.add(CaptionTextChangedEvent(text: text, windowWidth: width));
        });

        return Text(
          text,
          key: ValueKey('captions_${asrTextController.revision}'),
          textAlign: TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontSize: state.activeFontSize,
            fontWeight: state.activeIsBold
                ? FontWeight.bold
                : FontWeight.normal,
            color: Colors.white,
          ),
        );
      },
    ),
  );
}
