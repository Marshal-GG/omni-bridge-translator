import 'package:flutter/material.dart';

Widget buildSupportBranding() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/icon.png',
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 56,
              height: 56,
              color: Colors.white10,
              child: const Icon(
                Icons.help_outline_rounded,
                color: Colors.cyanAccent,
                size: 32,
              ),
            );
          },
        ),
      ),
      const SizedBox(width: 16),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Omni Bridge',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          Text(
            'SUPPORT & FEEDBACK',
            style: TextStyle(
              color: Colors.cyanAccent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    ],
  );
}
