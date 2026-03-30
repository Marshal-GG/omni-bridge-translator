import 'package:flutter/material.dart';

import 'package:omni_bridge/core/widgets/omni_header.dart';

Widget buildAccountHeader(BuildContext context, {required VoidCallback onBack}) {
  return OmniHeader(
    title: 'Account',
    icon: Icons.manage_accounts_rounded,
    onBack: onBack,
  );
}
