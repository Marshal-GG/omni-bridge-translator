import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../../core/window_manager.dart';
import 'components/startup_header.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    setToStartupPosition();
  }

  final List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      title: 'Welcome to Omni Bridge',
      description: 'Your personal AI-powered live translator and transcriber.',
      icon: Icons.language_rounded,
      color1: const Color(0xFF3B82F6),
      color2: const Color(0xFF8B5CF6),
    ),
    _OnboardingPageData(
      title: 'Capture Any Audio',
      description:
          'Switch seamlessly between translating your microphone input or your system\'s desktop audio.',
      icon: Icons.mic_external_on_rounded,
      color1: const Color(0xFF10B981),
      color2: const Color(0xFF3B82F6),
    ),
    _OnboardingPageData(
      title: 'Powered by AI',
      description:
          'Choose from state-of-the-art models like NVIDIA Riva and Meta LLaMA to get blazing fast results.',
      icon: Icons.auto_awesome_rounded,
      color1: const Color(0xFFF59E0B),
      color2: const Color(0xFFEF4444),
    ),
    _OnboardingPageData(
      title: 'Unobtrusive Overlay',
      description:
          'Pin the translation window on top of your games or meetings for instant subtitles anywhere.',
      icon: Icons.layers_rounded,
      color1: const Color(0xFFEC4899),
      color2: const Color(0xFF8B5CF6),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WindowBorder(
        color: Colors.white12,
        width: 1,
        child: Container(
          color: const Color(0xFF121212),
          child: Column(
            children: [
              buildStartupHeader(),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 600, // Slightly wider for onboarding text/icons
                    child: Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemCount: _pages.length,
                          itemBuilder: (context, index) {
                            return _OnboardingPageView(pageData: _pages[index]);
                          },
                        ),
                        
                        // Bottom Controls
                        Positioned(
                          bottom: 48,
                          left: 24,
                          right: 24,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Skip Button
                              TextButton(
                                onPressed: _finishOnboarding,
                                child: Text(
                                  'Skip',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              
                              // Indicators
                              Row(
                                children: List.generate(
                                  _pages.length,
                                  (index) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    height: 8,
                                    width: _currentPage == index ? 24 : 8,
                                    decoration: BoxDecoration(
                                      color: _currentPage == index
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
      
                              // Next / Finish Button
                              ElevatedButton(
                                onPressed: _onNext,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF121212),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                ),
                                child: Text(
                                  _currentPage == _pages.length - 1
                                      ? 'Get Started'
                                      : 'Next',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

class _OnboardingPageData {
  final String title;
  final String description;
  final IconData icon;
  final Color color1;
  final Color color2;

  _OnboardingPageData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color1,
    required this.color2,
  });
}

class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPageData pageData;

  const _OnboardingPageView({required this.pageData});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with glowing effect
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [pageData.color1, pageData.color2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: pageData.color1.withValues(alpha: 0.4),
                  blurRadius: 32,
                  spreadRadius: 8,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              pageData.icon,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 64),
          
          // Title
          Text(
            pageData.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          
          // Description
          Text(
            pageData.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 64), // Spacer for bottom controls
        ],
      ),
    );
  }
}
