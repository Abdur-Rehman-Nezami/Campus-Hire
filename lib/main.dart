import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'components/shared/skill_chip.dart';
import 'components/shared/match_score_badge.dart';
import 'components/shared/status_pill.dart';
import 'components/shared/initials_avatar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
      rethrow;
    }
  }
  runApp(const ProviderScope(child: CampusHireApp()));
}

class CampusHireApp extends StatelessWidget {
  const CampusHireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Hire',
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ComponentTestScreen extends StatelessWidget {
  const ComponentTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme & Components'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Typography', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 16),
            const Text('This is a body text displaying the Inter font. It should look clean and modern.'),
            const SizedBox(height: 32),

            Text('Skill Chips', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const SkillChip(label: 'Flutter', variant: SkillChipVariant.neutral),
                const SkillChip(label: 'Dart', variant: SkillChipVariant.neutral),
                const SkillChip(label: '#Paid', variant: SkillChipVariant.selected),
                const SkillChip(label: 'Python', variant: SkillChipVariant.matched),
                const SkillChip(label: 'Figma', variant: SkillChipVariant.missing),
              ],
            ),
            const SizedBox(height: 32),

            Text('Match Score Badges', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Row(
              spacing: 16,
              children: const [
                MatchScoreBadge(score: 0.85, variant: MatchBadgeVariant.subtle),
                MatchScoreBadge(score: 0.92, variant: MatchBadgeVariant.filled),
                MatchScoreBadge(score: 0.60, variant: MatchBadgeVariant.outlined),
              ],
            ),
            const SizedBox(height: 32),

            Text('Status Pills', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                StatusPill(status: 'Shortlisted'),
                StatusPill(status: 'Pending'),
                StatusPill(status: 'Rejected'),
                StatusPill(status: 'Urgent', isSolid: true),
                StatusPill(status: 'MVP Stage', isOutlined: true),
              ],
            ),
            const SizedBox(height: 32),

            Text('Initials Avatars', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Row(
              spacing: 16,
              children: const [
                InitialsAvatar(name: 'Abdur Rehman'),
                InitialsAvatar(name: 'Sarah Jenkins'),
                InitialsAvatar(name: 'Ali Raza Khan'),
              ],
            ),
            const SizedBox(height: 32),
            
            Text('Buttons', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Row(
              spacing: 16,
              children: [
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Primary'),
                ),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Outlined'),
                ),
              ],
            ),
            const SizedBox(height: 32),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dark Card Example', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text('This is how content looks inside a dark card container.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Theme(
              data: Theme.of(context).copyWith(
                cardTheme: Theme.of(context).cardTheme.copyWith(color: AppColors.cardLight),
              ),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Light Card Example', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textDark)),
                      const SizedBox(height: 8),
                      Text(
                        'This is how content looks inside a light card container.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textDark),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
