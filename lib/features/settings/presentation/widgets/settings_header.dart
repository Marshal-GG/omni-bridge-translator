import 'package:flutter/material.dart';
import 'package:omni_bridge/core/widgets/omni_header.dart';

Widget buildSettingsHeader(BuildContext context) {
  return OmniHeader(
    title: 'Settings',
    icon: Icons.settings_rounded,
    onBack: () => Navigator.pop(context),
  );
}
