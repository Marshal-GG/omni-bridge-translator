import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:omni_bridge/features/startup/presentation/blocs/startup_bloc.dart';
import 'package:omni_bridge/features/startup/presentation/blocs/startup_state.dart';
import 'package:omni_bridge/features/startup/presentation/blocs/startup_event.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';

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
            child: Container(
            color: AppColors.bgDeep, // Match login screen background
              child: Column(
                children: [
                  // Invisible drag area for the whole top section
                  Expanded(
                    child: WindowTitleBarBox(
                      child: MoveWindow(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Image.asset(
                                'assets/app/icons/icon.png',
                                width: 96,
                                height: 96,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 32),
                            const Text(
                              'Omni Bridge',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Progress bar at the bottom like Discord
                  Padding(
                    padding: const EdgeInsets.only(left: 32, right: 32, bottom: 40),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 6,
                        child: isIndeterminate
                            ? const LinearProgressIndicator(
                                backgroundColor: AppColors.bgElevated,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                              )
                            : LinearProgressIndicator(
                                value: progressValue,
                                backgroundColor: AppColors.bgElevated,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
