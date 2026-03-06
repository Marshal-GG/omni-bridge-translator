import 'package:flutter/material.dart';

Widget buildLoginInputs({
  required TextEditingController emailController,
  required TextEditingController passwordController,
}) {
  return Column(
    children: [
      TextField(
        controller: emailController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: 'Email',
          labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          prefixIcon: const Icon(
            Icons.email_outlined,
            color: Colors.white60,
            size: 20,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 16,
          ),
        ),
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: passwordController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        obscureText: true,
        decoration: InputDecoration(
          labelText: 'Password',
          labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          prefixIcon: const Icon(
            Icons.lock_outline,
            color: Colors.white60,
            size: 20,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 16,
          ),
        ),
      ),
    ],
  );
}
