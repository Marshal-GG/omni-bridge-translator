import 'package:flutter/material.dart';

Widget buildSupportFooter(BuildContext context) {
  return Wrap(
    spacing: 16,
    runSpacing: 12,
    alignment: WrapAlignment.center,
    children: [
      _buildFooterLink(context, 'FAQ', Colors.cyanAccent, () {
        // Find the FAQ link from the help center section if needed, 
        // or just point towards a general help route/URL.
        Navigator.of(context).pushNamed('/help-center'); // Or launchUrl if it's external
      }),
      _buildFooterLink(context, 'Settings', Colors.teal, () {
        Navigator.pushNamed(context, '/settings-overlay');
      }),
      _buildFooterLink(context, 'Account', Colors.purple, () {
        Navigator.pushNamed(context, '/account');
      }),
      _buildFooterLink(context, 'About', Colors.amber, () {
        Navigator.pushNamed(context, '/about');
      }),
      _buildFooterLink(context, 'Plans', Colors.lightBlue, () {
        Navigator.pushNamed(context, '/subscription');
      }),
    ],
  );
}

Widget _buildFooterLink(
  BuildContext context,
  String text,
  Color color,
  VoidCallback onTap,
) {
  return SizedBox(
    height: 36,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        foregroundColor: color.withValues(alpha: 0.9),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),
  );
}
