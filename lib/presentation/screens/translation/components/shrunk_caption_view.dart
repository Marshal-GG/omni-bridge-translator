import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import 'package:omni_bridge/presentation/screens/translation/bloc/translation_bloc.dart';
import 'package:omni_bridge/presentation/screens/translation/bloc/translation_event.dart';
import 'package:omni_bridge/presentation/screens/translation/bloc/translation_state.dart';
import 'package:omni_bridge/core/device/asr_text_controller.dart';

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
                    key: ValueKey(
                      'shrunk_captions_${asrTextController.revision}',
                    ),
                    textAlign: TextAlign.left,
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
          // Transparent drag region on top so dragging over text moves the window
          // onDoubleTap: () {} disables the default maximize on double-click
          Positioned.fill(child: MoveWindow(onDoubleTap: () {})),
        ],
      ),
    ),
  );
}
