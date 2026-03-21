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
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.tealAccent.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.tealAccent.withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 36,
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          backgroundImage: (user?.photoURL?.startsWith('http') == true)
              ? NetworkImage(user!.photoURL!)
              : null,
          child: (user?.photoURL?.startsWith('http') != true)
              ? Icon(
                  isAnon ? Icons.person_outline : Icons.person,
                  color: Colors.tealAccent,
                  size: 32,
                )
              : null,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        isAnon ? 'Guest User' : (user?.displayName ?? 'No Name'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      if (!isAnon)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            user?.email ?? '',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
        ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.tealAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.2)),
        ),
        child: Text(
          _providerLabel(isAnon, user).toUpperCase(),
          style: const TextStyle(
            color: Colors.tealAccent,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),
    ],
  );
}
