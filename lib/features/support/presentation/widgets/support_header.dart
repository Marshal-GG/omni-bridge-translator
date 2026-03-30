import 'package:flutter/material.dart';
import 'package:omni_bridge/core/widgets/omni_header.dart';

Widget buildSupportHeader(BuildContext context) {
  return OmniHeader(
    title: 'Support & Feedback',
    icon: Icons.help_outline,
    onBack: () => Navigator.pop(context),
  );
}
