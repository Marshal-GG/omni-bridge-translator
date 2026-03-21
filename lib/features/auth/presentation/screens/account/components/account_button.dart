import 'package:flutter/material.dart';

class AccountButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDanger;

  const AccountButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.isDanger,
  });

  @override
  State<AccountButton> createState() => _AccountButtonState();
}

class _AccountButtonState extends State<AccountButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final danger = widget.isDanger;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: widget.onPressed,
            icon: Icon(
              widget.icon,
              size: 16,
              color: danger
                  ? Colors.redAccent.withValues(alpha: 0.9)
                  : (_isHovered ? Colors.black : Colors.white70),
            ),
            label: Text(
              widget.label,
              style: TextStyle(
                color: danger
                    ? Colors.redAccent.withValues(alpha: 0.9)
                    : (_isHovered ? Colors.black : Colors.white70),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: danger
                  ? (_isHovered
                        ? Colors.redAccent.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.03))
                  : (_isHovered
                        ? Colors.tealAccent
                        : Colors.white.withValues(alpha: 0.05)),
              foregroundColor: danger ? Colors.redAccent : Colors.black,
              elevation: 0,
              shadowColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(
                  color: danger
                      ? Colors.redAccent.withValues(
                          alpha: _isHovered ? 0.4 : 0.2,
                        )
                      : (_isHovered ? Colors.tealAccent : Colors.white12),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
