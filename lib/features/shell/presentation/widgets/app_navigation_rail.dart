import 'package:flutter/material.dart';

import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/features/shell/presentation/blocs/app_shell_bloc.dart';
import 'package:omni_bridge/features/shell/presentation/blocs/app_shell_state.dart';
import 'package:omni_bridge/core/widgets/omni_card.dart';
import 'package:omni_bridge/core/widgets/omni_chip.dart';
import 'package:omni_bridge/core/navigation/app_router.dart';

class AppNavigationRail extends StatelessWidget {
  final String currentRoute;

  const AppNavigationRail({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.navRailWidth, // 256
      decoration: const BoxDecoration(
        color: AppColors.bgDeep,
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBranding(context),
          const SizedBox(height: 16),
          _buildSectionLabel('MENU'),
          _buildNavLinks(context),
          const Spacer(),
          _buildUserProfile(context),
        ],
      ),
    );
  }

  // ── Branding ──────────────────────────────────────────────────────────────

  Widget _buildBranding(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: GestureDetector(
        onTap: () {
          // Navigating to default settings if they click the brand
          if (currentRoute != AppRouter.settingsOverlay) {
             Navigator.pushReplacementNamed(context, AppRouter.settingsOverlay);
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: AppShapes.md,
              child: Image.asset(
                'assets/app/icons/icon.png',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.15),
                    borderRadius: AppShapes.md,
                  ),
                  child: const Icon(Icons.dashboard_rounded,
                      color: AppColors.accentCyan, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Omni Bridge',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.offWhite,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'DASHBOARD',
                  style: AppTextStyles.labelTiny.copyWith(
                    color: AppColors.accentCyan,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Section Label ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Text(
        text,
        style: AppTextStyles.labelTiny.copyWith(
          color: AppColors.white54.withValues(alpha: 0.6),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
          fontSize: 9,
        ),
      ),
    );
  }

  // ── Nav Links ─────────────────────────────────────────────────────────────

  Widget _buildNavLinks(BuildContext context) {
    return Column(
      children: [
        _NavTile(
          icon: Icons.settings_rounded,
          label: 'Settings',
          isActive: currentRoute == AppRouter.settingsOverlay,
          onTap: () => _navigate(context, AppRouter.settingsOverlay),
        ),
        _NavTile(
          icon: Icons.card_membership_rounded,
          label: 'Subscription',
          isActive: currentRoute == AppRouter.subscription,
          onTap: () => _navigate(context, AppRouter.subscription),
        ),
        _NavTile(
          icon: Icons.analytics_rounded,
          label: 'Usage Logs',
          isActive: currentRoute == AppRouter.usage,
          onTap: () => _navigate(context, AppRouter.usage),
        ),
        _NavTile(
          icon: Icons.support_agent_rounded,
          label: 'Help & Support',
          isActive: currentRoute == AppRouter.support,
          onTap: () => _navigate(context, AppRouter.support),
        ),
        _NavTile(
          icon: Icons.info_rounded,
          label: 'About',
          isActive: currentRoute == AppRouter.about,
          onTap: () => _navigate(context, AppRouter.about),
        ),
      ],
    );
  }

  void _navigate(BuildContext context, String routeName) {
    if (currentRoute != routeName) {
      // Use pushReplacementNamed to prevent stacking endless routes when navigating via side-bar
      // And we rely on PageRouteBuilder duration: zero transitions in AppRouter to make it seamless
      Navigator.pushReplacementNamed(context, routeName);
    }
  }

  // ── User Profile (reactive via BlocBuilder) ────────────────────

  Widget _buildUserProfile(BuildContext context) {
    return BlocBuilder<AppShellBloc, AppShellState>(
      builder: (context, state) {
        final user = state.currentUser;
        if (user == null) return const SizedBox.shrink();

        final name = user.displayName ?? user.email?.split('@').first ?? 'You';
        final email = user.email ?? '';
        final photoUrl = user.photoURL;
        final initials = name.isNotEmpty
            ? name
                .trim()
                .split(' ')
                .map((w) => w.isNotEmpty ? w[0] : '')
                .take(2)
                .join()
                .toUpperCase()
            : '?';

        final status = state.currentSubscriptionStatus;
        final planTier = status?.tier;
        final chipColor = (planTier?.toLowerCase() == 'trial')
            ? Colors.amberAccent
            : AppColors.accentCyan;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Tooltip(
            message: 'Manage account',
            child: GestureDetector(
              onTap: () {
                // Navigate to account. Account is usually a modal or push over the dashboard.
                // Push (not replacement) because account is a sub-page of settings/dashboard.
                Navigator.pushNamed(context, AppRouter.account);
              },
              child: OmniCard(
                baseColor: AppColors.surfaceLight,
                hasGlow: false,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: photoUrl != null && photoUrl.isNotEmpty
                            ? Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _Initials(initials: initials),
                              )
                            : _Initials(initials: initials),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.offWhite,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (planTier != null) ...[
                                const SizedBox(width: 4),
                                OmniChip(
                                  label: planTier.toUpperCase(),
                                  color: chipColor,
                                  fontSize: 8,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: AppTextStyles.labelTiny.copyWith(
                                color: AppColors.white54,
                                fontSize: 9,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Initials — centered initials text inside the avatar circle
// ─────────────────────────────────────────────────────────────────────────────

class _Initials extends StatelessWidget {
  final String initials;
  const _Initials({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.accentCyan,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav Tile — animated hover + active state
// ─────────────────────────────────────────────────────────────────────────────

class _NavTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.isActive || _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.accentCyan.withValues(alpha: 0.1)
                : (_hovered
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.transparent),
            borderRadius: AppShapes.md,
            border: widget.isActive
                ? Border.all(color: AppColors.accentCyan.withValues(alpha: 0.2))
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.isActive
                    ? AppColors.accentCyan
                    : (isHighlighted
                        ? AppColors.offWhite
                        : AppColors.white54),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    color: widget.isActive
                        ? AppColors.accentCyan
                        : (isHighlighted
                            ? AppColors.offWhite
                            : AppColors.white54),
                    fontWeight: widget.isActive
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
