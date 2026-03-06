import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/history_entry.dart';

Widget buildHistoryEntryItem(HistoryEntry entry) {
  final timeStr = DateFormat('HH:mm:ss').format(entry.timestamp);

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timestamp + lang pair
        Row(
          children: [
            Text(
              timeStr,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${entry.sourceLang} → ${entry.targetLang}',
                style: const TextStyle(color: Colors.tealAccent, fontSize: 9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Transcription
        Text(
          entry.transcription,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        if (entry.translation.isNotEmpty &&
            entry.translation != entry.transcription) ...[
          const SizedBox(height: 4),
          Text(
            entry.translation,
            style: const TextStyle(
              color: Colors.tealAccent,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ],
    ),
  );
}
