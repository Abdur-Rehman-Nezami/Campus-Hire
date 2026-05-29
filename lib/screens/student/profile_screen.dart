import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/user_provider.dart';
import '../../providers/skills_config_provider.dart';
import '../../theme/app_colors.dart';
import '../../components/shared/initials_avatar.dart';
import '../../components/shared/skill_chip.dart';
import '../../utils/upload_utils.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../providers/events_provider.dart';
import 'event_detail_screen.dart';
import 'networking_hub_screen.dart';
import '../splash_screen.dart';
import '../../services/ai_service.dart';
import '../../models/application_model.dart';

class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  final _bioController = TextEditingController();
  final Set<String> _selectedSkills = {};
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _isUploadingResume = false;
  bool _isLoadingRecommendations = false;
  List<Map<String, String>>? _recommendations;

  Future<void> _showPhotoUploadSheet(BuildContext context, String userId, String? currentPhotoUrl) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from gallery', style: TextStyle(color: AppColors.textLight)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final file = await UploadUtils.pickAndCompressImage();
                if (file == null) return;
                
                setState(() => _isUploadingPhoto = true);
                try {
                  final url = await UploadUtils.uploadFile(file, 'photos/$userId/photo.jpg');
                  await FirebaseFirestore.instance.collection('users').doc(userId).update({
                    'profilePhotoUrl': url,
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile photo updated!'), backgroundColor: AppColors.successGreen),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to upload photo: $e'), backgroundColor: AppColors.errorRed),
                  );
                } finally {
                  setState(() => _isUploadingPhoto = false);
                }
              },
            ),
            if (currentPhotoUrl != null && currentPhotoUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.errorRed),
                title: const Text('Remove photo', style: TextStyle(color: AppColors.errorRed)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  setState(() => _isUploadingPhoto = true);
                  try {
                    try {
                      await FirebaseStorage.instance.ref().child('photos/$userId/photo.jpg').delete();
                    } catch (_) {}
                    
                    await FirebaseFirestore.instance.collection('users').doc(userId).update({
                      'profilePhotoUrl': null,
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile photo removed!'), backgroundColor: AppColors.successGreen),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to remove photo: $e'), backgroundColor: AppColors.errorRed),
                    );
                  } finally {
                    setState(() => _isUploadingPhoto = false);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadResume() async {
    final file = await UploadUtils.pickPdf();
    if (file == null) return;

    setState(() => _isUploadingResume = true);
    try {
      final user = ref.read(userStreamProvider).value;
      if (user != null) {
        final url = await UploadUtils.uploadFile(file, 'resumes/${user.userId}/resume.pdf');
        await FirebaseFirestore.instance.collection('users').doc(user.userId).update({
          'resumeUrl': url,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resume uploaded successfully!'), backgroundColor: AppColors.successGreen),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload resume: $e'), backgroundColor: AppColors.errorRed),
      );
    } finally {
      setState(() => _isUploadingResume = false);
    }
  }

  Future<void> _replaceResume() => _uploadResume();

  Future<void> _viewResume(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open resume: $e'), backgroundColor: AppColors.errorRed),
      );
    }
  }

  Future<void> _fetchSkillRecommendations(List<String> studentSkills) async {
    setState(() {
      _isLoadingRecommendations = true;
    });

    try {
      final studentId = FirebaseAuth.instance.currentUser?.uid;
      if (studentId == null) return;

      final appsSnap = await FirebaseFirestore.instance
          .collection('applications')
          .where('studentId', isEqualTo: studentId)
          .get();

      if (appsSnap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Apply to jobs first to receive personalized recommendations.'),
              backgroundColor: Colors.amber,
            ),
          );
        }
        setState(() {
          _recommendations = [];
          _isLoadingRecommendations = false;
        });
        return;
      }

      final List<String> allAppliedRequiredSkills = [];
      double totalScore = 0.0;
      int count = 0;

      for (var doc in appsSnap.docs) {
        final app = ApplicationModel.fromMap(doc.data(), doc.id);
        allAppliedRequiredSkills.addAll(app.matchedSkills);
        allAppliedRequiredSkills.addAll(app.missingSkills);
        totalScore += app.matchScore;
        count++;
      }

      final double averageMatchScore = count > 0 ? (totalScore / count) : 0.0;

      final result = await AIService.getSkillRecommendations(
        studentSkills: studentSkills,
        allAppliedRequiredSkills: allAppliedRequiredSkills.toSet().toList(),
        averageMatchScore: averageMatchScore,
      );

      if (mounted) {
        setState(() {
          _recommendations = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load recommendations: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRecommendations = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Pre-populate fields from the current user data stream
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userStreamProvider).value;
      if (user != null) {
        _bioController.text = user.bio ?? '';
        setState(() {
          _selectedSkills.addAll(user.skills);
        });
      }
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    
    try {
      final user = ref.read(userStreamProvider).value;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.userId)
            .update({
          'bio': _bioController.text.trim(),
          'skills': _selectedSkills.toList(),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userStreamProvider);
    final skillsAsync = ref.watch(skillsConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: _isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : const Icon(Icons.check, color: AppColors.successGreen),
              onPressed: _isSaving ? null : _saveProfile,
            ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.errorRed))),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User profile not found.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Avatar + Basic Identity ──────────────────────────
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _showPhotoUploadSheet(context, user.userId, user.profilePhotoUrl),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            InitialsAvatar(
                              name: user.name,
                              radius: 52,
                              imageUrl: user.profilePhotoUrl,
                            ),
                            if (_isUploadingPhoto)
                              const CircleAvatar(
                                radius: 52,
                                backgroundColor: Colors.black54,
                                child: CircularProgressIndicator(color: AppColors.primary),
                              ),
                            if (!_isUploadingPhoto)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.primary,
                                  child: const Icon(Icons.camera_alt, size: 16, color: AppColors.textDark),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(user.name, style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: 6),
                      Text(
                        '${user.department ?? "Student"} · ${user.yearOfStudy ?? "1st"} Year',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textMutedLight),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_city, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            user.university,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ProfileStatChip(value: '${user.skills.length}', label: 'Skills'),
                          Container(width: 1, height: 30, color: AppColors.dividerDark, margin: const EdgeInsets.symmetric(horizontal: 16)),
                          _ProfileStatChip(value: user.yearOfStudy ?? '–', label: 'Year'),
                          Container(width: 1, height: 30, color: AppColors.dividerDark, margin: const EdgeInsets.symmetric(horizontal: 16)),
                          _ProfileStatChip(
                            value: (user.resumeUrl?.isNotEmpty == true) ? '✓' : '–',
                            label: 'Resume',
                            valueColor: (user.resumeUrl?.isNotEmpty == true) ? AppColors.successGreen : AppColors.textMutedLight,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // ─── Profile Completeness Banner ──────────────────────
                if (user.bio == null || user.bio!.isEmpty || user.skills.isEmpty || (user.resumeUrl == null || user.resumeUrl!.isEmpty)) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warningAmber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.warningAmber, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Complete your profile to improve your match scores with startups.',
                            style: TextStyle(color: AppColors.warningAmber, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 48, color: AppColors.dividerDark),

                // ─── Bio Section ──────────────────────────────────────
                Row(
                  children: [
                    const Icon(Icons.person_outline, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text('Bio', style: Theme.of(context).textTheme.headlineSmall),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isEditing)
                  TextField(
                    controller: _bioController,
                    maxLines: 3,
                    maxLength: 150,
                    decoration: const InputDecoration(
                      hintText: 'Tell startups about yourself...',
                      border: OutlineInputBorder(),
                    ),
                  )
                else
                  Text(
                    user.bio?.isNotEmpty == true ? user.bio! : 'No bio added yet. Tap edit above to add a bio.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: user.bio?.isNotEmpty == true ? AppColors.textLight : AppColors.textMutedLight,
                      height: 1.5,
                      fontStyle: user.bio?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                const Divider(height: 48, color: AppColors.dividerDark),

                // ─── Skills Section ───────────────────────────────────
                Row(
                  children: [
                    const Icon(Icons.code, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text('Skills', style: Theme.of(context).textTheme.headlineSmall),
                    const Spacer(),
                    if (!_isEditing && user.skills.isNotEmpty)
                      Text('${user.skills.length} added', style: const TextStyle(color: AppColors.textMutedLight, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isEditing)
                  skillsAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (err, _) => Text('Error: $err'),
                    data: (categories) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: categories.map((cat) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cat.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 8,
                                children: cat.skills.map((skill) {
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
                              const SizedBox(height: 16),
                            ],
                          );
                        }).toList(),
                      );
                    },
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 8,
                    children: user.skills.isEmpty
                        ? [const Text('No skills selected. Tap edit to add skills.', style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textMutedLight))]
                        : user.skills.map((s) => SkillChip(
                            label: s,
                            variant: SkillChipVariant.matched,
                          )).toList(),
                  ),
                const Divider(height: 48, color: AppColors.dividerDark),

                // ─── Resume Section ───────────────────────────────────
                Row(
                  children: [
                    const Icon(Icons.description_outlined, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text('Resume / CV', style: Theme.of(context).textTheme.headlineSmall),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isUploadingResume)
                  const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ))
                else if (user.resumeUrl == null || user.resumeUrl!.isEmpty)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: _uploadResume,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Resume (PDF only)'),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.dividerDark),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf, color: AppColors.errorRed, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('resume.pdf', style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Attached portfolio', style: TextStyle(color: AppColors.textMutedLight, fontSize: 12)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _viewResume(user.resumeUrl!),
                          child: const Text('View', style: TextStyle(color: AppColors.primary)),
                        ),
                        TextButton(
                          onPressed: _replaceResume,
                          child: const Text('Replace', style: TextStyle(color: AppColors.textMutedLight)),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 48, color: AppColors.dividerDark),

                // ─── AI Skill Recommendations Section ──────────────────
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.psychology_outlined, color: AppColors.primary, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'AI Skill Recommendations',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (_recommendations != null && !_isLoadingRecommendations)
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 20, color: AppColors.primary),
                                onPressed: () => _fetchSkillRecommendations(user.skills),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingRecommendations)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.0),
                              child: Column(
                                children: [
                                  CircularProgressIndicator(color: AppColors.primary),
                                  SizedBox(height: 12),
                                  Text('Analyzing your skill gaps...', style: TextStyle(color: AppColors.textMutedLight)),
                                ],
                              ),
                            ),
                          )
                        else if (_recommendations == null)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _fetchSkillRecommendations(user.skills),
                              icon: const Icon(Icons.bolt, size: 16),
                              label: const Text('Get Recommendations'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primary),
                                foregroundColor: AppColors.primary,
                              ),
                            ),
                          )
                        else if (_recommendations!.isEmpty)
                          const Text(
                            'Apply to jobs first to receive personalized recommendations.',
                            style: TextStyle(color: AppColors.textMutedLight, fontStyle: FontStyle.italic),
                          )
                        else
                          Column(
                            children: _recommendations!.map((rec) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        rec['skill'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        rec['reason'] ?? '',
                                        style: const TextStyle(color: AppColors.textLight, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 48, color: AppColors.dividerDark),

                // ─── My Network Section ───────────────────────────────
                Row(
                  children: [
                    const Icon(Icons.people_outline, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text('My Network', style: Theme.of(context).textTheme.headlineSmall),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NetworkingHubScreen()),
                        );
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Manage Network', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                          SizedBox(width: 4),
                          Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.dividerDark),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                Text('${user.followerCount}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textLight)),
                                const SizedBox(height: 4),
                                const Text('Followers', style: TextStyle(fontSize: 12, color: AppColors.textMutedLight)),
                              ],
                            ),
                            Container(width: 1, height: 30, color: AppColors.dividerDark),
                            Column(
                              children: [
                                Text('${user.followingCount}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textLight)),
                                const SizedBox(height: 4),
                                const Text('Following', style: TextStyle(fontSize: 12, color: AppColors.textMutedLight)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 48, color: AppColors.dividerDark),

                // ─── My RSVPs Section ───────────────────────────────
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text('My RSVPs', style: Theme.of(context).textTheme.headlineSmall),
                  ],
                ),
                const SizedBox(height: 16),
                ref.watch(eventsStreamProvider).when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Text('Error loading events: $err'),
                  data: (events) {
                    final rsvpd = events.where((e) => e.attendees.contains(user.userId)).toList();
                    if (rsvpd.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.dividerDark),
                        ),
                        child: const Center(
                          child: Text(
                            'You haven\'t RSVP\'d to any events yet.\nDiscover seminars and hackathons in the Events tab!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textMutedLight, height: 1.5, fontSize: 13),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rsvpd.length,
                      itemBuilder: (context, index) {
                        final event = rsvpd[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: InitialsAvatar(
                              name: event.startupName ?? 'S',
                              radius: 20,
                              imageUrl: event.logoUrl,
                            ),
                            title: Text(
                              event.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                '${DateFormat('MMM d · h:mm a').format(event.dateTime)} · ${event.location}',
                                style: const TextStyle(color: AppColors.textMutedLight, fontSize: 12),
                              ),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMutedLight),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventDetailScreen(event: event),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const Divider(height: 48, color: AppColors.dividerDark),

                // Seed complete app ecosystem
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: _isSaving ? null : () async {
                    setState(() => _isSaving = true);
                    try {
                      final batch = FirebaseFirestore.instance.batch();
                      final listingsCol = FirebaseFirestore.instance.collection('listings');
                      final startupsCol = FirebaseFirestore.instance.collection('startups');
                      final usersCol = FirebaseFirestore.instance.collection('users');
                      final appsCol = FirebaseFirestore.instance.collection('applications');
                      final eventsCol = FirebaseFirestore.instance.collection('events');
                      final followsCol = FirebaseFirestore.instance.collection('follows');
                      
                      // 1. Seed startups
                      final startupIds = ['seed-startup-1', 'seed-startup-2', 'seed-startup-3', 'seed-startup-4'];
                      final mockStartups = [
                        {
                          'startupId': 'seed-startup-1',
                          'name': 'TechLab COMSATS',
                          'sector': 'AI/ML',
                          'university': 'COMSATS',
                          'description': 'Building next-generation smart tools for university classrooms. Integrating AI models to streamline learning flows.',
                          'founderId': 'seed-founder-1',
                          'createdAt': Timestamp.now(),
                        },
                        {
                          'startupId': 'seed-startup-2',
                          'name': 'UniDesign Co.',
                          'sector': 'SaaS',
                          'university': 'NUST',
                          'description': 'SaaS workspace providing tailored visual templates and productivity systems for academic departments across Pakistan.',
                          'founderId': 'seed-founder-2',
                          'createdAt': Timestamp.now(),
                        },
                        {
                          'startupId': 'seed-startup-3',
                          'name': 'C-Apps',
                          'sector': 'FinTech',
                          'university': 'FAST-NUCES',
                          'description': 'Empowering university students with secure micro-payments, smart wallets, and budget planning solutions.',
                          'founderId': 'seed-founder-3',
                          'createdAt': Timestamp.now(),
                        },
                        {
                          'startupId': 'seed-startup-4',
                          'name': 'StartupNest',
                          'sector': 'EdTech',
                          'university': 'LUMS',
                          'description': 'Help build our community presence across platforms. You will design Canva slides, write engaging copies, and analyze growth metrics.',
                          'founderId': 'seed-founder-4',
                          'createdAt': Timestamp.now(),
                        }
                      ];

                      for (var startup in mockStartups) {
                        final doc = startupsCol.doc(startup['startupId'] as String);
                        batch.set(doc, startup);
                      }

                      // 2. Seed Mock User Profiles (Students and Founders)
                      final mockUsers = [
                        // Students
                        {
                          'name': 'Zainab Ali',
                          'email': 'zainab@campus.com',
                          'university': 'NUST',
                          'department': 'Software Engineering',
                          'yearOfStudy': '4th',
                          'bio': 'UI/UX Designer. Focused on creating beautiful design systems, intuitive visual layouts, and interactive micro-animations. Extensive Figma experience.',
                          'skills': ['Figma', 'Prototyping', 'Adobe XD', 'Canva'],
                          'role': 'student',
                          'createdAt': Timestamp.now(),
                        },
                        {
                          'name': 'Haris Ahmed',
                          'email': 'haris@campus.com',
                          'university': 'COMSATS',
                          'department': 'Computer Science',
                          'yearOfStudy': '2nd',
                          'bio': 'Backend engineer focused on database query scaling, RESTful API design, and containerization. Enjoys solving complex system architectures.',
                          'skills': ['Node.js', 'PostgreSQL', 'Docker', 'REST APIs', 'Git'],
                          'role': 'student',
                          'createdAt': Timestamp.now(),
                        },
                        // Founders
                        {
                          'name': 'Ali Raza',
                          'email': 'ali@techlab.com',
                          'university': 'COMSATS',
                          'role': 'founder',
                          'startupId': 'seed-startup-1',
                          'createdAt': Timestamp.now(),
                        },
                        {
                          'name': 'Sara Khan',
                          'email': 'sara@unidesign.com',
                          'university': 'NUST',
                          'role': 'founder',
                          'startupId': 'seed-startup-2',
                          'createdAt': Timestamp.now(),
                        },
                        {
                          'name': 'Kamran Ahmed',
                          'email': 'kamran@capps.com',
                          'university': 'FAST-NUCES',
                          'role': 'founder',
                          'startupId': 'seed-startup-3',
                          'createdAt': Timestamp.now(),
                        },
                        {
                          'name': 'Bilal Shah',
                          'email': 'bilal@startupnest.com',
                          'university': 'LUMS',
                          'role': 'founder',
                          'startupId': 'seed-startup-4',
                          'createdAt': Timestamp.now(),
                        }
                      ];

                      // We want specific doc IDs for the founders so listings link correctly
                      final mockStudents = mockUsers.where((u) => u['role'] == 'student').toList();
                      final mockFounders = mockUsers.where((u) => u['role'] == 'founder').toList();

                      for (var student in mockStudents) {
                        final doc = usersCol.doc();
                        batch.set(doc, student);
                      }

                      for (var i = 0; i < mockFounders.length; i++) {
                        final doc = usersCol.doc('seed-founder-${i + 1}');
                        batch.set(doc, mockFounders[i]);
                      }

                      // 3. Seed listings
                      final mockListings = [
                        {
                          'title': 'Flutter Developer',
                          'startupName': 'TechLab COMSATS',
                          'startupSector': 'AI/ML',
                          'university': 'COMSATS',
                          'requiredSkills': ['Flutter', 'Dart', 'Firebase', 'Git'],
                          'type': 'internship',
                          'locationType': 'hybrid',
                          'compensationType': 'paid',
                          'compensationDetails': 'Rs 15,000',
                          'description': 'Join our team to build high-quality mobile applications for local campuses. You will collaborate on UI designs, Firebase integrations, and state management using Riverpod.',
                          'deadline': Timestamp.fromDate(DateTime.now().add(const Duration(days: 10))),
                          'status': 'open',
                          'createdAt': Timestamp.now(),
                          'founderId': 'seed-founder-1',
                          'startupId': 'seed-startup-1',
                        },
                        {
                          'title': 'UI/UX Designer',
                          'startupName': 'UniDesign Co.',
                          'startupSector': 'SaaS',
                          'university': 'NUST',
                          'requiredSkills': ['Figma', 'Prototyping', 'Adobe XD'],
                          'type': 'job',
                          'locationType': 'remote',
                          'compensationType': 'negotiable',
                          'compensationDetails': 'Equity option',
                          'description': 'Looking for a creative mind to lead our new visual design system. You will create wireframes, components, and high-fidelity prototype flows in Figma.',
                          'deadline': Timestamp.fromDate(DateTime.now().add(const Duration(days: 15))),
                          'status': 'open',
                          'createdAt': Timestamp.now(),
                          'founderId': 'seed-founder-2',
                          'startupId': 'seed-startup-2',
                        },
                        {
                          'title': 'Backend Engineer (Node)',
                          'startupName': 'C-Apps',
                          'startupSector': 'FinTech',
                          'university': 'FAST-NUCES',
                          'requiredSkills': ['Node.js', 'PostgreSQL', 'Docker', 'REST APIs'],
                          'type': 'job',
                          'locationType': 'on-site',
                          'compensationType': 'paid',
                          'compensationDetails': 'Rs 25,000',
                          'description': 'Scale our core payment APIs and databases. You will manage PostgreSQL query optimization, server deployments, and containerization.',
                          'deadline': Timestamp.fromDate(DateTime.now().add(const Duration(days: 5))),
                          'status': 'open',
                          'createdAt': Timestamp.now(),
                          'founderId': 'seed-founder-3',
                          'startupId': 'seed-startup-3',
                        },
                        {
                          'title': 'Social Media Manager',
                          'startupName': 'StartupNest',
                          'startupSector': 'EdTech',
                          'university': 'LUMS',
                          'requiredSkills': ['Canva', 'Copywriting', 'Marketing'],
                          'type': 'internship',
                          'locationType': 'remote',
                          'compensationType': 'unpaid',
                          'compensationDetails': 'Certificate + Mentorship',
                          'description': 'Help build our community presence across platforms. You will design Canva slides, write engaging copies, and analyze growth metrics.',
                          'deadline': Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
                          'status': 'open',
                          'createdAt': Timestamp.now(),
                          'founderId': 'seed-founder-4',
                          'startupId': 'seed-startup-4',
                        }
                      ];

                      final createdListingIds = <String>[];
                      for (var i = 0; i < mockListings.length; i++) {
                        final doc = listingsCol.doc('seed-listing-${i + 1}');
                        batch.set(doc, mockListings[i]);
                        createdListingIds.add(doc.id);
                      }

                      // 4. Seed Applications linked directly to the current student
                      final studentSkills = user.skills;
                      final matchScores = [
                        // Calculate actual scores based on student's active skills
                        studentSkills.contains('Flutter') ? 100 : 50,
                        studentSkills.contains('Figma') ? 100 : 0,
                      ];

                      final mockApps = [
                        {
                          'studentId': user.userId,
                          'listingId': 'seed-listing-1',
                          'coverNote': 'Flutter development is my absolute passion! I have designed three modular dashboards and would love to join TechLab to build the smart classroom application.',
                          'status': 'shortlisted',
                          'matchScore': matchScores[0],
                          'matchedSkills': studentSkills.where((s) => ['Flutter', 'Dart', 'Firebase', 'Git'].contains(s)).toList(),
                          'missingSkills': ['Flutter', 'Dart', 'Firebase', 'Git'].where((s) => !studentSkills.contains(s)).toList(),
                          'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 2))),
                          'startupId': 'seed-startup-1',
                        },
                        {
                          'studentId': user.userId,
                          'listingId': 'seed-listing-2',
                          'coverNote': 'Your product-led SaaS growth strategy looks excellent. I have designed interactive web prototypes and would love to lead visual layout layouts here.',
                          'status': 'pending',
                          'matchScore': matchScores[1],
                          'matchedSkills': studentSkills.where((s) => ['Figma', 'Prototyping', 'Adobe XD'].contains(s)).toList(),
                          'missingSkills': ['Figma', 'Prototyping', 'Adobe XD'].where((s) => !studentSkills.contains(s)).toList(),
                          'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 12))),
                          'startupId': 'seed-startup-2',
                        }
                      ];

                      for (var i = 0; i < mockApps.length; i++) {
                        final doc = appsCol.doc('seed-app-${user.userId}-${i + 1}');
                        batch.set(doc, mockApps[i]);
                      }

                      // 5. Seed Events
                      final mockEvents = [
                        {
                          'startupId': 'seed-startup-1',
                          'founderId': 'seed-founder-1',
                          'title': 'Flutter Dev & Firebase Integration Workshop',
                          'description': 'A hands-on coding workshop teaching state management, real-time sync with Firebase, and compiling Flutter web app dashboards.',
                          'type': 'workshop',
                          'dateTime': Timestamp.fromDate(DateTime.now().add(const Duration(days: 2))),
                          'location': 'Zoom Video Meeting Room',
                          'isOnline': true,
                          'meetingUrl': 'https://zoom.us/j/999888777666',
                          'speakers': ['Dr. Usman Ali', 'Engr. Ayesha Malik'],
                          'attendees': [],
                          'createdAt': Timestamp.now(),
                          'startupName': 'TechLab COMSATS',
                        },
                        {
                          'startupId': 'seed-startup-2',
                          'founderId': 'seed-founder-2',
                          'title': 'UI/UX Design Systems Seminar',
                          'description': 'Explore industry-standard workflows in Figma, building consistent UI components, component libraries, and dynamic animation prototypes.',
                          'type': 'seminar',
                          'dateTime': Timestamp.fromDate(DateTime.now().add(const Duration(days: 4))),
                          'location': 'Seminar Hall C, NUST',
                          'isOnline': false,
                          'speakers': ['Sara Khan (Lead Designer, UniDesign)'],
                          'attendees': [],
                          'createdAt': Timestamp.now(),
                          'startupName': 'UniDesign Co.',
                        },
                        {
                          'startupId': 'seed-startup-3',
                          'founderId': 'seed-founder-3',
                          'title': 'Fintech Startup Networking Mixer',
                          'description': 'Informal networking session bringing together finance professionals, developers, and aspiring entrepreneurs to collaborate on microfinance systems.',
                          'type': 'networking',
                          'dateTime': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))),
                          'location': 'FAST Cafeteria Courtyard',
                          'isOnline': false,
                          'speakers': ['Bilal Ahmed (Co-founder, C-Apps)'],
                          'attendees': [],
                          'createdAt': Timestamp.now(),
                          'startupName': 'C-Apps',
                        }
                      ];

                      for (var i = 0; i < mockEvents.length; i++) {
                        final doc = eventsCol.doc('seed-event-${i + 1}');
                        batch.set(doc, mockEvents[i]);
                      }

                      // 6. Seed Follows
                      final mockFollows = [
                        {
                          'followerId': user.userId,
                          'followingId': 'seed-founder-1',
                          'createdAt': Timestamp.now(),
                        },
                        {
                          'followerId': user.userId,
                          'followingId': 'seed-founder-2',
                          'createdAt': Timestamp.now(),
                        },
                        {
                          'followerId': 'seed-founder-1',
                          'followingId': user.userId,
                          'createdAt': Timestamp.now(),
                        }
                      ];

                      for (final follow in mockFollows) {
                        final docId = '${follow['followerId']}_${follow['followingId']}';
                        batch.set(followsCol.doc(docId), follow);
                      }

                      // Update current user followers/following counts
                      batch.update(usersCol.doc(user.userId), {
                        'followerCount': 1,
                        'followingCount': 2,
                      });

                      // 7. Seed Startup Follows
                      final startupFollowsCol = FirebaseFirestore.instance.collection('startup_follows');
                      final mockStartupFollows = [
                        {
                          'userId': user.userId,
                          'startupId': 'seed-startup-1',
                          'createdAt': Timestamp.now(),
                        },
                        {
                          'userId': user.userId,
                          'startupId': 'seed-startup-2',
                          'createdAt': Timestamp.now(),
                        }
                      ];

                      for (final follow in mockStartupFollows) {
                        final docId = '${follow['userId']}_${follow['startupId']}';
                        batch.set(startupFollowsCol.doc(docId), follow);
                      }

                      // Update startup followerCount
                      batch.update(startupsCol.doc('seed-startup-1'), {'followerCount': 1});
                      batch.update(startupsCol.doc('seed-startup-2'), {'followerCount': 1});

                      await batch.commit();

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('App Ecosystem & Applications seeded successfully!'),
                          backgroundColor: AppColors.successGreen,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to seed: $e'), backgroundColor: AppColors.errorRed),
                      );
                    } finally {
                      setState(() => _isSaving = false);
                    }
                  },
                  child: const Text('Seed Complete App Demo Data', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                
                // Sign out button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorRed,
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const SplashScreen()),
                        (route) => false,
                      );
                    }
                  },
                  child: const Text('Sign Out', style: TextStyle(color: AppColors.textLight)),
                ),
                const SizedBox(height: 48),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileStatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const _ProfileStatChip({required this.value, required this.label, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: valueColor ?? AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMutedLight, fontSize: 11),
        ),
      ],
    );
  }
}
