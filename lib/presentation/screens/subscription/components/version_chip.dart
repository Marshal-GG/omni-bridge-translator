import 'package:flutter/material.dart';

Widget buildVersionChip({required String label}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white10),
    ),
    child: Text(
      'OMNI BRIDGE $label'.toUpperCase(),
      style: const TextStyle(
        color: Colors.white24,
        fontSize: 8,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    ),
  );
}
