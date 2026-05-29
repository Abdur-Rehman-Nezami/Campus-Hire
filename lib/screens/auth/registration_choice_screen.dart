import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'student_registration_step_1.dart';
import 'founder_registration_step_1.dart';

class RegistrationChoiceScreen extends StatefulWidget {
  const RegistrationChoiceScreen({super.key});

  @override
  State<RegistrationChoiceScreen> createState() => _RegistrationChoiceScreenState();
}

class _RegistrationChoiceScreenState extends State<RegistrationChoiceScreen> {
  String? _selectedRole;

  void _onContinue() {
    if (_selectedRole == 'student') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StudentRegistrationStep1Screen()),
      );
    } else if (_selectedRole == 'founder') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FounderRegistrationStep1Screen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How do you want to use Campus Hire?',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 32),
              
              // Student Card
              _RoleCard(
                title: 'Student',
                subtitle: 'Find internships, jobs, or co-founder roles',
                icon: Icons.school_outlined,
                isSelected: _selectedRole == 'student',
                onTap: () => setState(() => _selectedRole = 'student'),
              ),
              const SizedBox(height: 16),
              
              // Founder Card
              _RoleCard(
                title: 'Startup founder',
                subtitle: 'Post gigs and find talented students',
                icon: Icons.rocket_launch_outlined,
                isSelected: _selectedRole == 'founder',
                onTap: () => setState(() => _selectedRole = 'founder'),
              ),
              
              const Spacer(),
              ElevatedButton(
                onPressed: _selectedRole != null ? _onContinue : null,
                child: const Text('Continue'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.cardDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.dividerDark,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? AppColors.primary : AppColors.textLight,
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMutedLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
