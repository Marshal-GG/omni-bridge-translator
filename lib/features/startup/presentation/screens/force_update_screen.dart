import 'package:flutter/material.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/core/widgets/omni_card.dart';
import 'package:omni_bridge/core/widgets/omni_chip.dart';
import 'package:omni_bridge/core/widgets/omni_header.dart';
import 'package:omni_bridge/core/widgets/omni_window_layout.dart';
import 'package:omni_bridge/features/startup/presentation/notifiers/update_notifier.dart';
import 'package:omni_bridge/features/startup/presentation/widgets/update_download_button.dart';

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return OmniWindowLayout(
      child: Column(
        children: [
          OmniHeader(
            title: 'Update Required',
            icon: Icons.system_update_alt_rounded,
          ),
          const Divider(height: 1, color: AppColors.cardBorder),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final notifier = UpdateNotifier.instance;
    final message =
        notifier.forceUpdateMessage ??
        'A critical update is required to continue using Omni Bridge.';
    final url =
        notifier.releaseUrl ??
        'https://github.com/Marshal-GG/omni-bridge-translator/releases';
    final version = notifier.latestVersion ?? 'New Version';

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxDashboardWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl,
            ),
            child: OmniCard(
              baseColor: AppColors.accentRed,
              hasGlow: true,
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  OmniCard(
                    baseColor: AppColors.accentRed,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: const Icon(
                      Icons.system_update_alt_rounded,
                      size: 40,
                      color: AppColors.accentRed,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Title
                  Text('Update Required', style: AppTextStyles.display),

                  const SizedBox(height: AppSpacing.sm),

                  // Version chip
                  OmniChip(
                    label: 'v$version',
                    color: AppColors.accentRed,
                    fontSize: 13,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Message
                  Text(
                    message,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Download button
                  UpdateDownloadButton(
                    releaseUrl: url,
                    downloadUrl: notifier.downloadUrl,
                    primary: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
