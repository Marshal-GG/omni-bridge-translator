import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

Widget buildAccountHeader({required VoidCallback onBack}) {
  return SizedBox(
    height: 32,
    child: Row(
      children: [
        // ── Back button ───────────────────────────────────────────────
        SizedBox(
          width: 32,
          height: 32,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 15,
              color: Colors.white38,
            ),
            tooltip: 'Back to Translator',
            onPressed: onBack,
          ),
        ),
        const SizedBox(width: 4),
        const Icon(
          Icons.manage_accounts_rounded,
          size: 14,
          color: Colors.tealAccent,
        ),
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
        ),
      ],
    ),
  );
}
