import 'package:flutter/material.dart';
import 'package:omni_bridge/core/widgets/omni_header.dart';

Widget buildUsageHeader(BuildContext context) {
  return OmniHeader(
    title: 'Usage Dashboard',
    icon: Icons.analytics_rounded,
    onBack: () => Navigator.pop(context),
  );
}
