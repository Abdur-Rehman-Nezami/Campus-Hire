import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import 'home/student_shell.dart';
import 'home/founder_shell.dart';
import 'auth/welcome_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndRoute();
  }

  Future<void> _checkAuthAndRoute() async {
    // Show splash for at least 1.5s
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted) return;

    final authUser = ref.read(currentUserProvider);
    
    if (authUser == null) {
      // Not logged in -> Welcome
      _navigateReplace(const WelcomeScreen());
    } else {
      // Logged in, we need the user document to know the role
      // Wait for user provider to emit a non-null value or complete
      final userDoc = await ref.read(userStreamProvider.future);
      
      if (!mounted) return;

      if (userDoc == null) {
        // Doc not found or error, back to welcome
        _navigateReplace(const WelcomeScreen());
      } else if (userDoc.role == 'founder') {
        _navigateReplace(const FounderShell());
      } else {
        _navigateReplace(const StudentShell());
      }
    }
  }

  void _navigateReplace(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(32),
          ),
          child: const Icon(
            Icons.rocket_launch,
            size: 64,
            color: AppColors.textDark,
          ),
        ),
      ),
    );
  }
}
