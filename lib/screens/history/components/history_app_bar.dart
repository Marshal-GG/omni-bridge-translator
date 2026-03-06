import 'package:flutter/material.dart';
import '../../../core/services/history_service.dart';

PreferredSizeWidget buildHistoryAppBar(BuildContext context) {
  return AppBar(
    backgroundColor: const Color(0xFF141414),
    title: Row(
      children: const [
        Icon(Icons.history, size: 18, color: Colors.tealAccent),
        SizedBox(width: 10),
        Text(
          'Translation History',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 18),
        tooltip: 'Clear History',
        onPressed: () => HistoryService.instance.clear(),
      ),
      const SizedBox(width: 8),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(0),
      child: Container(height: 1, color: Colors.white12),
    ),
  );
}
