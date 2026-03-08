import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import 'components/overlay_content.dart';

class TranslationScreen extends StatelessWidget {
  const TranslationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}
