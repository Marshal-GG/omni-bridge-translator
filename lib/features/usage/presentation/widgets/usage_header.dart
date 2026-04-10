import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/core/widgets/omni_header.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_bloc.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_event.dart';

Widget buildUsageHeader(BuildContext context) {
  return OmniHeader(
    title: 'Usage Dashboard',
    icon: Icons.analytics_rounded,
    onBack: () => Navigator.pop(context),
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.white60),
        tooltip: 'Refresh',
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
        splashRadius: 16,
        onPressed: () =>
            context.read<UsageBloc>().add(const LoadUsageStats(refresh: true)),
      ),
    ],
  );
}
