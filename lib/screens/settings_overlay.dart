import 'package:flutter/material.dart';

class SettingsOverlay extends StatelessWidget {
  const SettingsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              title: const Text("Language"),
              subtitle: const Text("Select translation language"),
              onTap: () {
                // Add language selection code here
              },
            ),
            ListTile(
              title: const Text("Overlay Position"),
              subtitle: const Text("Adjust overlay position"),
              onTap: () {
                // Add overlay position adjustment code here
              },
            ),
          ],
        ),
      ),
    );
  }
}