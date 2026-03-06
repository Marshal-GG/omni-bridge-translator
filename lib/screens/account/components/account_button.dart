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
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: widget.onPressed,
            icon: Icon(
              widget.icon,
              size: 17,
              color: danger
                  ? Colors.redAccent
                  : (_isHovered ? Colors.black87 : Colors.white70),
            ),
            label: Text(
              widget.label,
              style: TextStyle(
                color: danger
                    ? Colors.redAccent
                    : (_isHovered ? Colors.black87 : Colors.white70),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: danger
                  ? (_isHovered
                        ? Colors.redAccent.withValues(alpha: 0.15)
                        : Colors.transparent)
                  : (_isHovered ? Colors.tealAccent : Colors.white10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: danger
                      ? Colors.redAccent.withValues(alpha: 0.5)
                      : Colors.white12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
