import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

Widget buildHistoryHeader(BuildContext context, {required VoidCallback onClear}) {
  return Container(
    height: 32,
    color: Colors.black26,
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
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(
          Icons.history,
          size: 14,
          color: Colors.tealAccent,
        ),
        const SizedBox(width: 8),
        const Text(
          'History',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(child: MoveWindow()),
        
        // ── Action: Clear ─────────────────────────────────────────────
        SizedBox(
          width: 32,
          height: 32,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 14,
              color: Colors.white38,
            ),
            tooltip: 'Clear History',
            onPressed: onClear,
          ),
        ),

        MinimizeWindowButton(
          colors: WindowButtonColors(iconNormal: Colors.white38),
        ),
        CloseWindowButton(
          colors: WindowButtonColors(
            iconNormal: Colors.white38,
            mouseOver: Colors.redAccent,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
