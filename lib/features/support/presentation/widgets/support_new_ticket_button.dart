import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class SupportNewTicketButton extends StatefulWidget {
  final VoidCallback onTap;
  
  const SupportNewTicketButton({
    super.key,
    required this.onTap,
  });

  @override
  State<SupportNewTicketButton> createState() => _SupportNewTicketButtonState();
}

class _SupportNewTicketButtonState extends State<SupportNewTicketButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 56, // Standard floating action button height
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isHovered 
                    ? [AppColors.accentCyan, AppColors.accentTeal]
                    : [AppColors.accentCyan.withValues(alpha: 0.85), AppColors.accentTeal.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28), // Fully rounded pill
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentCyan.withValues(alpha: _isHovered ? 0.4 : 0.2),
                  blurRadius: _isHovered ? 24 : 12,
                  spreadRadius: _isHovered ? 2 : 0,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit_square, // A more premium representation of "new ticket"
                  size: 20,
                  color: AppColors.surfaceDarkest.withValues(alpha: 0.9),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'New Ticket',
                  style: TextStyle(
                    color: AppColors.surfaceDarkest.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
