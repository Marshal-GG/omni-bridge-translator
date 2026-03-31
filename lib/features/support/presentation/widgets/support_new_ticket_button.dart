import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/omni_tinted_button.dart';

class SupportNewTicketButton extends StatelessWidget {
  final VoidCallback onTap;
  
  const SupportNewTicketButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OmniTintedButton(
      label: 'New Ticket',
      icon: Icons.edit_square,
      color: AppColors.accentTeal,
      onPressed: onTap,
    );
  }
}
