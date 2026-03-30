import 'package:flutter/material.dart';

Widget buildLoginBranding() {
  return Column(
    children: [
      Image.asset('assets/app/icons/icon.png', width: 72, height: 72),
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
