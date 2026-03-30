import 'package:flutter/material.dart';

import 'package:omni_bridge/core/widgets/omni_header.dart';

Widget buildSubscriptionHeader(BuildContext context) {
  return OmniHeader(
    title: 'Subscription Plans',
    icon: Icons.workspace_premium_rounded,
    onBack: () => Navigator.pop(context),
  );
}
