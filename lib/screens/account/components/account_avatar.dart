import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

String _providerLabel(bool isAnon, User? user) {
  if (isAnon) return 'Guest Mode';
  final providerId = user?.providerData.firstOrNull?.providerId ?? '';
  switch (providerId) {
    case 'google.com':
      return 'Google Account';
    case 'password':
      return 'Email Account';
    default:
      return providerId.isNotEmpty ? providerId : 'Signed In';
  }
}

Widget buildAccountAvatar(User? user, bool isAnon) {
  return Column(
    children: [
      CircleAvatar(
        radius: 36,
        backgroundColor: Colors.tealAccent.withValues(alpha: 0.12),
        backgroundImage: (user?.photoURL?.startsWith('http') == true)
            ? NetworkImage(user!.photoURL!)
            : null,
        child: (user?.photoURL?.startsWith('http') != true)
            ? Icon(
                isAnon ? Icons.person_outline : Icons.person,
                color: Colors.tealAccent,
                size: 36,
              )
            : null,
      ),
      const SizedBox(height: 14),
      Text(
        isAnon ? 'Anonymous User' : (user?.displayName ?? 'No Name'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      if (!isAnon)
        Text(
          user?.email ?? '',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.tealAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
        ),
        child: Text(
          _providerLabel(isAnon, user),
          style: const TextStyle(
            color: Colors.tealAccent,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}
