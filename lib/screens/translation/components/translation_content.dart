import 'package:flutter/material.dart';
import '../bloc/translation_state.dart';
import '../../../core/services/asr_text_controller.dart';

Widget buildTranslationContent(BuildContext context, TranslationState state) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: ValueListenableBuilder<String>(
      valueListenable: asrTextController,
      builder: (_, text, _) {
        return Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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
