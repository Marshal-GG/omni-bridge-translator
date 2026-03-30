import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../../../features/subscription/data/datasources/subscription_remote_datasource.dart';
import '../../../../features/subscription/data/models/subscription_dto.dart';
import 'package:omni_bridge/core/widgets/omni_card.dart';
import 'package:omni_bridge/core/widgets/omni_chip.dart';

/// Left-hand navigation panel for the Support screen.
///
/// Shows the Omni branding, a [New Ticket] action button, a list of
/// ticket-filter nav items, and the current user's profile at the bottom.
/// The profile card reacts to auth state via [AuthRemoteDataSource.currentUser].
class SupportNavigationRail extends StatelessWidget {
  const SupportNavigationRail({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.navRailWidth, // 256
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBranding(),
          const SizedBox(height: 16),
          _buildSectionLabel('TICKETS'),
          _buildNavLinks(),
          const Spacer(),
          _buildUserProfile(),
        ],
      ),
    );
  }

  // ── Branding ──────────────────────────────────────────────────────────────

  Widget _buildBranding() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
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
                child: const Icon(Icons.support_agent_rounded,
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
                'SUPPORT CENTER',
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

  Widget _buildNavLinks() {
    return const Column(
      children: [
        _NavTile(icon: Icons.forum_rounded,           label: 'All Tickets', isActive: true),
        _NavTile(icon: Icons.bolt_rounded,            label: 'Active'),
        _NavTile(icon: Icons.hourglass_empty_rounded, label: 'Pending'),
        _NavTile(icon: Icons.check_circle_rounded,    label: 'Resolved'),
        _NavTile(icon: Icons.inventory_2_rounded,     label: 'Archive'),
      ],
    );
  }

  // ── User Profile (reactive via ValueListenableBuilder) ────────────────────

  Widget _buildUserProfile() {
    return ValueListenableBuilder(
      valueListenable: AuthRemoteDataSource.instance.currentUser,
      builder: (context, user, _) {
        if (user == null) return const SizedBox.shrink();

        final name =
            user.displayName ?? user.email?.split('@').first ?? 'You';
        final email = user.email ?? '';
        final photoUrl = user.photoURL;
        final initials = name.isNotEmpty
            ? name
                .trim()
                .split(' ')
                .map((w) => w[0])
                .take(2)
                .join()
                .toUpperCase()
            : '?';

        return StreamBuilder<SubscriptionStatus>(
          stream: SubscriptionRemoteDataSource.instance.statusStream,
          initialData: SubscriptionRemoteDataSource.instance.currentStatus,
          builder: (context, snapshot) {
            final status = snapshot.data;
            final planTier = status?.tier;
            final chipColor = (planTier?.toLowerCase() == 'trial')
                ? Colors.amberAccent
                : AppColors.accentCyan;

            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Tooltip(
                message: 'Manage account',
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/account'),
                  child: OmniCard(
                    baseColor: Colors.amberAccent,
                    hasGlow: true,
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
// Nav Tile — animated hover + active state, optional badge
// ─────────────────────────────────────────────────────────────────────────────

class _NavTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _NavTile({
    required this.icon,
    required this.label,
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
        onTap: () {},
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
