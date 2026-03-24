import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

Widget buildAccountHeader(BuildContext context, {required VoidCallback onBack}) {
  return SizedBox(
    height: 32,
    child: Row(
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 15,
              color: Colors.white38,
            ),
            splashRadius: 16,
            padding: EdgeInsets.zero,
          ),
        ),
        const Icon(Icons.manage_accounts_rounded, size: 14, color: Colors.tealAccent),
        const SizedBox(width: 8),
        const Text(
          'Account',
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
