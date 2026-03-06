import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

Widget buildAccountEmailInfo(User? user) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Email',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            const Icon(Icons.email_outlined, size: 15, color: Colors.white38),
            const SizedBox(width: 10),
            Text(
              user?.email ?? '—',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const Spacer(),
            if (user?.emailVerified == true)
              const Icon(Icons.verified, size: 14, color: Colors.tealAccent),
          ],
        ),
      ),
    ],
  );
}
