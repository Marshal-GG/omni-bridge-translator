import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

Widget buildSupportHeader(BuildContext context) {
  return Container(
    height: 32,
    color: Colors.transparent,
    child: WindowTitleBarBox(
    child: Row(
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 15, color: Colors.white38),
            splashRadius: 16,
            padding: EdgeInsets.zero,
          ),
        ),
        const Icon(Icons.help_outline, size: 14, color: Colors.cyanAccent),
        const SizedBox(width: 8),
        const Text(
          'Support & Feedback',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white38,
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
          onPressed: () => appWindow.close(),
        ),
      ],
    ),
    ),
  );
}
