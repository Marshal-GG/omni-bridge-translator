import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

Widget buildStartupHeader() {
  return SizedBox(
    height: 32,
    child: Row(
      children: [
        const SizedBox(width: 12),
        const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white38),
        const SizedBox(width: 8),
        const Text(
          'Omni Bridge',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
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
  );
}
