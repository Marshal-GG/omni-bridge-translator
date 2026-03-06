import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import '../bloc/translation_bloc.dart';
import '../bloc/translation_event.dart';
import '../bloc/translation_state.dart';
import '../../../core/services/asr_text_controller.dart';

Widget buildShrunkCaptionView(
  BuildContext context,
  TranslationState state,
  double opacity,
) {
  final bloc = context.read<TranslationBloc>();

  return GestureDetector(
    onTap: () => bloc.add(ToggleShrinkEvent()),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Stack(
        children: [
          MoveWindow(),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder<String>(
                valueListenable: asrTextController,
                builder: (ctx, text, _) {
                  // Ask bloc to measure line count and resize the window
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final width = MediaQuery.sizeOf(ctx).width;
                    bloc.add(
                      CaptionTextChangedEvent(text: text, windowWidth: width),
                    );
                  });

                  return Text(
                    text.isEmpty ? 'Listening...' : text,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: state.activeFontSize,
                      fontWeight: state.activeIsBold
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: Colors.white,
                      shadows: const [
                        Shadow(offset: Offset(1, 1), blurRadius: 3),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
