import 'package:flutter/material.dart';
import 'package:omni_bridge/core/widgets/omni_header.dart';
import 'package:omni_bridge/features/auth/presentation/screens/account/components/admin_panel.dart';
import 'package:omni_bridge/features/shell/presentation/widgets/app_dashboard_shell.dart';
import 'package:omni_bridge/core/navigation/app_router.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppDashboardShell(
      currentRoute: AppRouter.admin,
      header: OmniHeader(
        title: 'Admin Panel',
        icon: Icons.admin_panel_settings_rounded,
        onBack: () => Navigator.pop(context),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: const AdminPanel(),
          ),
        ),
      ),
    );
  }
}
