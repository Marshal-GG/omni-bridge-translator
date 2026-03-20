import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import 'package:omni_bridge/presentation/screens/translation/bloc/translation_bloc.dart';
import 'package:omni_bridge/presentation/screens/translation/bloc/translation_state.dart';
import 'package:omni_bridge/presentation/screens/translation/components/translation_header.dart';
import 'package:omni_bridge/presentation/screens/translation/components/translation_content.dart';
import 'package:omni_bridge/presentation/screens/translation/components/shrunk_caption_view.dart';

Widget buildOverlayContent(BuildContext context) {
  return BlocListener<TranslationBloc, TranslationState>(
    listenWhen: (prev, curr) =>
        prev.navToSubscriptionTrigger != curr.navToSubscriptionTrigger,
    listener: (context, state) {
      Navigator.pushNamed(context, '/subscription');
    },
    child: BlocBuilder<TranslationBloc, TranslationState>(
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
                child: Stack(
                  children: [
                    buildTranslationContent(context, state),
                    // Transparent drag region so dragging on the caption text
                    // moves the window instead of selecting/blocking interaction.
                    Positioned.fill(child: MoveWindow(onDoubleTap: () {})),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
