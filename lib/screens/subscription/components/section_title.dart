import 'package:flutter/material.dart';

Widget buildSectionTitle({required String title, required String subtitle}) {
  return Column(
    children: [
      Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: const TextStyle(color: Colors.white38, fontSize: 13),
      ),
    ],
  );
}
