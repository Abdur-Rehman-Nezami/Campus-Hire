import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listings_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/application_model.dart';
import '../../theme/app_colors.dart';
import '../../components/shared/skill_chip.dart';
import '../../components/shared/match_score_badge.dart';
import '../../utils/upload_utils.dart';
import '../../services/ai_service.dart';

class ApplyBottomSheet extends ConsumerStatefulWidget {
  final MatchedListing matchedListing;

  const ApplyBottomSheet({super.key, required this.matchedListing});

  @override
  ConsumerState<ApplyBottomSheet> createState() => _ApplyBottomSheetState();
}

class _ApplyBottomSheetState extends ConsumerState<ApplyBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _coverNoteController = TextEditingController();
  bool _isLoading = false;
  bool _isGenerating = false;

  // Resume attachment:
  // null = no resume, 'profile' = use profile resume, 'custom' = upload custom
  String? _resumeAttachMode;
  String? _customResumeUrl;
  bool _isUploadingResume = false;

  Future<void> _pickCustomResume(String userId) async {
    final file = await UploadUtils.pickPdf();
    if (file == null) return;
    setState(() => _isUploadingResume = true);
    try {
      final url = await UploadUtils.uploadFile(file, 'application_resumes/$userId/${DateTime.now().millisecondsSinceEpoch}.pdf');
      setState(() {
        _customResumeUrl = url;
        _resumeAttachMode = 'custom';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload resume: $e'), backgroundColor: AppColors.errorRed),
      );
    } finally {
      setState(() => _isUploadingResume = false);
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authUser = ref.read(currentUserProvider);
      if (authUser == null) throw Exception('User not logged in');

      final listing = widget.matchedListing.listing;

      final userProfile = ref.read(userStreamProvider).value;
      String? finalResumeUrl;
      if (_resumeAttachMode == 'custom') {
        finalResumeUrl = _customResumeUrl;
      } else if (_resumeAttachMode == 'profile') {
        finalResumeUrl = userProfile?.resumeUrl;
      }

      final application = ApplicationModel(
        applicationId: '', // Set by Firestore
        listingId: listing.listingId,
        startupId: listing.startupId,
        studentId: authUser.uid,
        coverNote: _coverNoteController.text.trim(),
        matchScore: widget.matchedListing.score,
        matchedSkills: widget.matchedListing.matchedSkills,
        missingSkills: widget.matchedListing.missingSkills,
        status: 'pending',
        createdAt: DateTime.now(),
        resumeUrl: finalResumeUrl,
      );

      final docRef = FirebaseFirestore.instance.collection('applications').doc();
      await docRef.set(application.toMap());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application submitted successfully!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(context, true); // Return true to indicate successful submission
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildResumeAttachRow() {
    final userProfile = ref.watch(userStreamProvider).value;
    final hasProfileResume = userProfile?.resumeUrl != null && userProfile!.resumeUrl!.isNotEmpty;
    final authUser = ref.watch(currentUserProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attach Resume (Optional)', style: TextStyle(
          color: AppColors.textLight,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        )),
        const SizedBox(height: 12),

        // Profile Resume option — only shown if profile has a resume
        if (hasProfileResume)
          _resumeOptionTile(
            icon: Icons.person,
            label: 'Use my profile resume',
            subtitle: 'Attach the PDF already on your profile',
            isSelected: _resumeAttachMode == 'profile',
            onTap: () => setState(() => _resumeAttachMode = _resumeAttachMode == 'profile' ? null : 'profile'),
          ),

        if (hasProfileResume) const SizedBox(height: 8),

        // Custom upload option
        if (_isUploadingResume)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(color: AppColors.primary),
          ))
        else
          _resumeOptionTile(
            icon: Icons.upload_file,
            label: _resumeAttachMode == 'custom' ? 'Custom resume uploaded ✓' : 'Upload a different PDF',
            subtitle: _resumeAttachMode == 'custom' ? 'Tap to replace' : 'Upload a new file specifically for this role',
            isSelected: _resumeAttachMode == 'custom',
            onTap: () => _pickCustomResume(authUser!.uid),
          ),

        // No resume option / clear
        if (_resumeAttachMode != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() {
              _resumeAttachMode = null;
              _customResumeUrl = null;
            }),
            child: Text(
              'Apply without resume',
              style: TextStyle(color: AppColors.textMutedLight, fontSize: 13, decoration: TextDecoration.underline),
            ),
          ),
        ],
      ],
    );
  }

  Widget _resumeOptionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.12) : AppColors.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.dividerDark, width: isSelected ? 1.5 : 1.0),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textMutedLight, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textLight,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  )),
                  Text(subtitle, style: TextStyle(color: AppColors.textMutedLight, fontSize: 11)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.matchedListing.listing;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: const BoxDecoration(
          color: AppColors.scaffoldBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pull handle
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.dividerDark,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                Text(
                  'Apply for ${listing.title}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  listing.startupName ?? 'Startup',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Match score row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Match Score',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    MatchScoreBadge(
                      score: widget.matchedListing.score,
                      variant: MatchBadgeVariant.filled,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Matching skills list
                Text(
                  'Matching Skills',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textMutedLight,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.matchedListing.matchedSkills.isEmpty
                      ? [const Text('No skills matched. You can still apply!', style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textMutedLight))]
                      : widget.matchedListing.matchedSkills.map((s) => SkillChip(
                          label: s,
                          variant: SkillChipVariant.matched,
                        )).toList(),
                ),
                const SizedBox(height: 24),
                
                // Cover note header with AI generation button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cover Note',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textLight, fontWeight: FontWeight.bold),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isGenerating
                          ? null
                          : () async {
                              setState(() => _isGenerating = true);
                              try {
                                final userProfile = ref.read(userStreamProvider).value;
                                if (userProfile == null) return;

                                // Fetch tagline from Firestore
                                final startupSnap = await FirebaseFirestore.instance
                                    .collection('startups')
                                    .doc(listing.startupId)
                                    .get();
                                final tagline = startupSnap.data()?['tagline'] as String? ?? '';

                                final note = await AIService.generateCoverNote(
                                  studentName: userProfile.name,
                                  studentSkills: userProfile.skills,
                                  listingTitle: listing.title,
                                  listingDescription: listing.description,
                                  startupName: listing.startupName ?? 'Startup',
                                  startupTagline: tagline,
                                  matchedSkills: widget.matchedListing.matchedSkills,
                                  missingSkills: widget.matchedListing.missingSkills,
                                  matchPercent: (widget.matchedListing.score * 100).toInt(),
                                );

                                if (note != null) {
                                  _coverNoteController.text = note;
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Couldn't generate right now — write your own"),
                                        backgroundColor: AppColors.errorRed,
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Couldn't generate right now — write your own"),
                                      backgroundColor: AppColors.errorRed,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _isGenerating = false);
                                }
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.auto_awesome, size: 14),
                      label: Text(_isGenerating ? 'Generating...' : 'Generate with AI'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Cover note input
                TextFormField(
                  controller: _coverNoteController,
                  decoration: const InputDecoration(
                    labelText: 'Why are you a good fit?',
                    border: OutlineInputBorder(),
                    helperText: 'Max 300 characters',
                    alignLabelWithHint: true,
                  ),
                  maxLength: 300,
                  maxLines: 4,
                  validator: (v) => v!.isEmpty ? 'Please enter a cover note' : null,
                ),
                const SizedBox(height: 24),

                // Resume attachment section
                _buildResumeAttachRow(),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _submitApplication,
                  child: _isLoading 
                      ? const SizedBox(
                          height: 20, 
                          width: 20, 
                          child: CircularProgressIndicator(color: AppColors.textDark, strokeWidth: 2)
                        )
                      : const Text('Submit Application'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
