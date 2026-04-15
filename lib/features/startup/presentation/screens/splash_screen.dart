import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:omni_bridge/features/startup/presentation/blocs/startup_bloc.dart';
import 'package:omni_bridge/features/startup/presentation/blocs/startup_state.dart';
import 'package:omni_bridge/features/startup/presentation/blocs/startup_event.dart';
import 'package:omni_bridge/core/widgets/splash_visual.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );

    // Make sure we trigger the initialization event!
    context.read<StartupBloc>().add(const StartupInitializeEvent());
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<StartupBloc, StartupState>(
      listener: (context, state) {
        if (state is StartupNavigateToHome) {
          Navigator.of(context).pushReplacementNamed('/translation-overlay');
        } else if (state is StartupNavigateToForceUpdate) {
          Navigator.of(context).pushReplacementNamed('/force_update');
        } else if (state is StartupNavigateToOnboarding) {
          Navigator.of(context).pushReplacementNamed('/onboarding');
        } else if (state is StartupFailure) {
          Navigator.of(context).pushReplacementNamed('/onboarding');
        }
      },
      builder: (context, state) {
        String statusText = "Starting up...";
        double progressValue = 0.0;
        bool isIndeterminate = true;

        if (state is StartupProgress) {
          statusText = state.message;
          progressValue = state.progress;
          isIndeterminate = false;
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: WindowBorder(
            color: Colors.white12,
            width: 1,
            child: SplashVisual(
              pulseAnimation: _pulseAnimation,
              statusText: statusText,
              isIndeterminate: isIndeterminate,
              progressValue: progressValue,
              draggable: true,
            ),
          ),
        );
      },
    );
  }
}
