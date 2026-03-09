import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/translation_bloc.dart';
import '../bloc/translation_state.dart';
import 'translation_header.dart';
import 'translation_content.dart';
import 'shrunk_caption_view.dart';

Widget buildOverlayContent(BuildContext context) {
  return BlocBuilder<TranslationBloc, TranslationState>(
    builder: (context, state) {
      final opacity = state.activeOpacity;

      if (state.isShrunk) {
        return buildShrunkCaptionView(context, state, opacity);
      }

      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: opacity),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            buildTranslationHeader(context, state),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: buildTranslationContent(context, state),
            ),
          ],
        ),
      );
    },
  );
}
