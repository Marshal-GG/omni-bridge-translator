import 'package:flutter/material.dart';

Widget buildLoginBranding() {
  return Column(
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.tealAccent.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.translate_rounded,
          size: 44,
          color: Colors.tealAccent,
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Omni Bridge',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      const Text(
        'Live AI Translator',
        style: TextStyle(color: Colors.white54, fontSize: 13),
      ),
    ],
  );
}
