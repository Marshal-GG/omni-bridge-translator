import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

Widget buildSettingsHeader(BuildContext context) {
  return SizedBox(
    height: 32,
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 16,
            color: Colors.white38,
          ),
          splashRadius: 16,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const Icon(Icons.settings_rounded, size: 14, color: Colors.white38),
        const SizedBox(width: 8),
        const Text(
          'Settings',
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
