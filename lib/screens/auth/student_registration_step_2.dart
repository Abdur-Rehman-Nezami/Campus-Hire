import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_colors.dart';
import '../../components/shared/skill_chip.dart';
import '../../providers/skills_config_provider.dart';
import '../../models/user_model.dart';
import '../home/student_shell.dart';

class StudentRegistrationStep2Screen extends ConsumerStatefulWidget {
  final String name;
  final String email;
  final String password;
  final String university;
  final String department;
  final String yearOfStudy;

  const StudentRegistrationStep2Screen({
    super.key,
    required this.name,
    required this.email,
    required this.password,
    required this.university,
    required this.department,
    required this.yearOfStudy,
  });

  @override
  ConsumerState<StudentRegistrationStep2Screen> createState() => _StudentRegistrationStep2ScreenState();
}

class _StudentRegistrationStep2ScreenState extends ConsumerState<StudentRegistrationStep2Screen> {
  final Set<String> _selectedSkills = {};
  bool _isLoading = false;

  Future<void> _createAccount() async {
    if (_selectedSkills.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: widget.email,
        password: widget.password,
      );

      final userModel = UserModel(
        userId: userCredential.user!.uid,
        name: widget.name,
        email: widget.email,
        university: widget.university,
        department: widget.department,
        yearOfStudy: widget.yearOfStudy,
        skills: _selectedSkills.toList(),
        role: 'student',
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userModel.userId)
          .set(userModel.toMap());

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const StudentShell()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skillsAsync = ref.watch(skillsConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your Skills')),
      body: SafeArea(
        child: skillsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading skills: $err')),
          data: (categories) {
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24.0),
                    children: [
                      Text('Select your top skills', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        'This helps us match you with the right startups.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMutedLight),
                      ),
                      const SizedBox(height: 24),
                      ...categories.map((category) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(category.name, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 12,
                              children: category.skills.map((skill) {
                                final isSelected = _selectedSkills.contains(skill);
                                return SkillChip(
                                  label: skill,
                                  variant: isSelected ? SkillChipVariant.selected : SkillChipVariant.neutral,
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedSkills.remove(skill);
                                      } else {
                                        _selectedSkills.add(skill);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ElevatedButton(
                    onPressed: _selectedSkills.isNotEmpty && !_isLoading ? _createAccount : null,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: AppColors.textDark)
                        : const Text('Create account'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
