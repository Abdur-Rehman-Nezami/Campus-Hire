import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../../providers/user_provider.dart';
import '../../providers/startup_provider.dart';
import '../../theme/app_colors.dart';
import '../../components/shared/initials_avatar.dart';
import '../../utils/upload_utils.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../splash_screen.dart';
import 'create_event_screen.dart';
import '../../services/ai_service.dart';

class FounderProfileScreen extends ConsumerStatefulWidget {
  const FounderProfileScreen({super.key});

  @override
  ConsumerState<FounderProfileScreen> createState() => _FounderProfileScreenState();
}

class _FounderProfileScreenState extends ConsumerState<FounderProfileScreen> {
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _sectorController = TextEditingController();
  final _universityController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingLogo = false;
  bool _isUploadingPhoto = false;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;

  Future<void> _uploadStartupLogo(String startupId) async {
    final file = await UploadUtils.pickAndCompressImage();
    if (file == null) return;

    setState(() => _isUploadingLogo = true);
    try {
      final url = await UploadUtils.uploadFile(file, 'logos/$startupId/logo.jpg');
      await FirebaseFirestore.instance.collection('startups').doc(startupId).update({
        'logoUrl': url,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Startup logo updated successfully!'), backgroundColor: AppColors.successGreen),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload logo: $e'), backgroundColor: AppColors.errorRed),
      );
    } finally {
      setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _showFounderPhotoUploadSheet(BuildContext context, String userId, String? currentPhotoUrl) async {
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final startup = ref.read(startupStreamProvider).value;
      if (startup != null) {
        _nameController.text = startup.name;
        _taglineController.text = startup.tagline;
        _sectorController.text = startup.sector ?? '';
        _universityController.text = startup.university;
        _descriptionController.text = startup.description ?? '';
      }
    });
  }

  Future<void> _saveStartupProfile() async {
    if (_nameController.text.trim().isEmpty || _universityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Startup name and university are required.'), backgroundColor: AppColors.errorRed),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final startup = ref.read(startupStreamProvider).value;
      if (startup != null) {
        // 1. Update startup doc
        await FirebaseFirestore.instance
            .collection('startups')
            .doc(startup.startupId)
            .update({
          'name': _nameController.text.trim(),
          'tagline': _taglineController.text.trim(),
          'sector': _sectorController.text.trim(),
          'university': _universityController.text.trim(),
          'description': _descriptionController.text.trim(),
        });

        // 2. Also propagate startup name updates to any listings this startup has posted
        final listingsSnapshot = await FirebaseFirestore.instance
            .collection('listings')
            .where('startupId', isEqualTo: startup.startupId)
            .get();

        final batch = FirebaseFirestore.instance.batch();
        for (var doc in listingsSnapshot.docs) {
          batch.update(doc.reference, {
            'startupName': _nameController.text.trim(),
            'startupSector': _sectorController.text.trim(),
            'university': _universityController.text.trim(),
          });
        }
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Startup profile updated successfully!'), backgroundColor: AppColors.successGreen),
          );
          setState(() => _isEditing = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save details: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userStreamProvider);
    final startupAsync = ref.watch(startupStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Founder Dashboard'),
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
              onPressed: _isSaving ? null : _saveStartupProfile,
            ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.errorRed))),
        data: (user) {
          if (user == null) return const Center(child: Text('User profile not found.'));

          return startupAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.errorRed))),
            data: (startup) {
              if (startup == null) return const Center(child: Text('Startup profile not found.'));

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Founder Info Avatar & Basic details
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => _uploadStartupLogo(startup.startupId),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                InitialsAvatar(
                                  name: startup.name,
                                  radius: 48,
                                  imageUrl: startup.logoUrl,
                                ),
                                if (_isUploadingLogo)
                                  const CircleAvatar(
                                    radius: 48,
                                    backgroundColor: Colors.black54,
                                    child: CircularProgressIndicator(color: AppColors.primary),
                                  ),
                                if (!_isUploadingLogo)
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
                          Text(startup.name, style: Theme.of(context).textTheme.displaySmall),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () => _showFounderPhotoUploadSheet(context, user.userId, user.profilePhotoUrl),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    InitialsAvatar(
                                      name: user.name,
                                      radius: 16,
                                      imageUrl: user.profilePhotoUrl,
                                    ),
                                    if (_isUploadingPhoto)
                                      const CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.black54,
                                        child: SizedBox(
                                          width: 10,
                                          height: 10,
                                          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Founder: ${user.name}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textMutedLight),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${startup.sector ?? "Tech"} · ${startup.university}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMutedLight),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 48, color: AppColors.dividerDark),

                    // Edit Mode / View Mode
                    if (_isEditing) ...[
                      Text('Edit Startup Profile', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Startup Name', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _taglineController,
                        decoration: const InputDecoration(labelText: 'Startup Tagline', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _sectorController,
                        decoration: const InputDecoration(labelText: 'Industry Sector (e.g. SaaS, EdTech)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _universityController,
                        decoration: const InputDecoration(labelText: 'Campus University Base', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Startup Description', border: OutlineInputBorder(), alignLabelWithHint: true),
                      ),
                      
                      // Analyze my pitch button
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _isAnalyzing
                              ? null
                              : () async {
                                  if (_nameController.text.trim().isEmpty ||
                                      _taglineController.text.trim().isEmpty ||
                                      _descriptionController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Fill in your startup details first'),
                                        backgroundColor: AppColors.errorRed,
                                      ),
                                    );
                                    return;
                                  }

                                  setState(() => _isAnalyzing = true);
                                  try {
                                    final result = await AIService.analyzeStartupPitch(
                                      startupName: _nameController.text.trim(),
                                      tagline: _taglineController.text.trim(),
                                      description: _descriptionController.text.trim(),
                                      sector: _sectorController.text.trim(),
                                      stage: startup.stage,
                                    );
                                    if (result != null) {
                                      setState(() {
                                        _analysisResult = result;
                                      });
                                    } else {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Analysis unavailable right now'),
                                            backgroundColor: AppColors.errorRed,
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Analysis failed: $e'),
                                          backgroundColor: AppColors.errorRed,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isAnalyzing = false);
                                    }
                                  }
                                },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            foregroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: _isAnalyzing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                )
                              : const Icon(Icons.analytics_outlined),
                          label: Text(_isAnalyzing ? 'Analyzing Pitch...' : 'Analyze my pitch'),
                        ),
                      ),

                      // Pitch Analysis Card
                      if (_analysisResult != null) ...[
                        const SizedBox(height: 20),
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Clarity Score Row
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: () {
                                          final score = _analysisResult!['clarityScore'] as int? ?? 0;
                                          if (score >= 70) return AppColors.successGreen.withOpacity(0.15);
                                          if (score >= 40) return Colors.amber.withOpacity(0.15);
                                          return AppColors.errorRed.withOpacity(0.15);
                                        }(),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${_analysisResult!['clarityScore'] ?? 0}',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: () {
                                            final score = _analysisResult!['clarityScore'] as int? ?? 0;
                                            if (score >= 70) return AppColors.successGreen;
                                            if (score >= 40) return Colors.amber;
                                            return AppColors.errorRed;
                                          }(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Pitch clarity score',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24, color: AppColors.dividerDark),

                                // Strengths
                                Text('What works', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.successGreen, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                ...((_analysisResult!['strengths'] as List? ?? []).map((strength) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.check_circle_outline, color: AppColors.successGreen, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(strength.toString(), style: const TextStyle(color: AppColors.textLight, fontSize: 13))),
                                        ],
                                      ),
                                    ))),
                                const SizedBox(height: 16),

                                // Weaknesses
                                Text('Improve this', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.amber, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                ...((_analysisResult!['weaknesses'] as List? ?? []).map((weakness) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.warning_amber_outlined, color: Colors.amber, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(weakness.toString(), style: const TextStyle(color: AppColors.textLight, fontSize: 13))),
                                        ],
                                      ),
                                    ))),
                                const SizedBox(height: 16),

                                // Suggested Tagline
                                Text('Suggested Tagline', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardDark,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.dividerDark),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '"${_analysisResult!['suggestedTagline'] ?? ''}"',
                                          style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.textLight),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.copy, size: 18, color: AppColors.textMutedLight),
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: _analysisResult!['suggestedTagline'] ?? ''));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Copied to clipboard'), backgroundColor: AppColors.successGreen),
                                          );
                                        },
                                      ),
                                      TextButton(
                                        child: const Text('Use this'),
                                        onPressed: () {
                                          _taglineController.text = _analysisResult!['suggestedTagline'] ?? '';
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Improved Description
                                Text('Improved Description', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardDark,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.dividerDark),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _analysisResult!['improvedDescription'] ?? '',
                                        style: const TextStyle(color: AppColors.textLight, fontSize: 13),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.copy, size: 18, color: AppColors.textMutedLight),
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: _analysisResult!['improvedDescription'] ?? ''));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Copied to clipboard'), backgroundColor: AppColors.successGreen),
                                              );
                                            },
                                          ),
                                          TextButton(
                                            child: const Text('Use this'),
                                            onPressed: () {
                                              _descriptionController.text = _analysisResult!['improvedDescription'] ?? '';
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: TextButton(
                                    child: const Text('Dismiss', style: TextStyle(color: AppColors.errorRed)),
                                    onPressed: () {
                                      setState(() {
                                        _analysisResult = null;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      if (startup.tagline.isNotEmpty) ...[
                        Text('Startup Tagline', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary)),
                        const SizedBox(height: 4),
                        Text(
                          startup.tagline,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: AppColors.textLight),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Text('Startup Description', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      Text(
                        startup.description?.isNotEmpty == true ? startup.description! : 'No startup description added yet. Tap edit above to define details.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                          color: startup.description?.isNotEmpty == true ? AppColors.textLight : AppColors.textMutedLight,
                          fontStyle: startup.description?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                    ],

                    const Divider(height: 48, color: AppColors.dividerDark),

                    // Seed complete app ecosystem (Founder Perspective)
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
                          final usersCol = FirebaseFirestore.instance.collection('users');
                          final appsCol = FirebaseFirestore.instance.collection('applications');

                          // 1. Seed Student Profiles
                          final students = [
                            {
                              'uid': 'seed-student-1',
                              'data': {
                                'name': 'Aisha Khan',
                                'email': 'aisha@campus.com',
                                'university': startup.university,
                                'department': 'Computer Science',
                                'yearOfStudy': '3rd',
                                'bio': 'Passionate mobile developer specializing in high-fidelity Flutter applications and state management. Looking for startup internships to build real products.',
                                'skills': ['Flutter', 'Dart', 'Firebase', 'Git', 'REST APIs'],
                                'role': 'student',
                                'createdAt': Timestamp.now(),
                              }
                            },
                            {
                              'uid': 'seed-student-2',
                              'data': {
                                'name': 'Zainab Ali',
                                'email': 'zainab@campus.com',
                                'university': startup.university,
                                'department': 'Software Engineering',
                                'yearOfStudy': '4th',
                                'bio': 'UI/UX Designer. Focused on creating beautiful design systems, intuitive visual layouts, and interactive micro-animations. Extensive Figma experience.',
                                'skills': ['Figma', 'Prototyping', 'Adobe XD', 'Canva'],
                                'role': 'student',
                                'createdAt': Timestamp.now(),
                              }
                            },
                            {
                              'uid': 'seed-student-3',
                              'data': {
                                'name': 'Haris Ahmed',
                                'email': 'haris@campus.com',
                                'university': startup.university,
                                'department': 'Computer Science',
                                'yearOfStudy': '2nd',
                                'bio': 'Backend engineer focused on database query scaling, RESTful API design, and containerization. Enjoys solving complex system architectures.',
                                'skills': ['Node.js', 'PostgreSQL', 'Docker', 'REST APIs', 'Git'],
                                'role': 'student',
                                'createdAt': Timestamp.now(),
                              }
                            }
                          ];

                          for (var s in students) {
                            final doc = usersCol.doc(s['uid'] as String);
                            batch.set(doc, s['data']!);
                          }

                          // 2. Seed listings under current startup
                          final mockListings = [
                            {
                              'title': 'Flutter Developer',
                              'startupName': startup.name,
                              'startupSector': startup.sector ?? 'Tech',
                              'university': startup.university,
                              'requiredSkills': ['Flutter', 'Dart', 'Firebase', 'Git'],
                              'type': 'internship',
                              'locationType': 'hybrid',
                              'compensationType': 'paid',
                              'compensationDetails': 'Rs 15,000',
                              'description': 'Join our team to build high-quality mobile applications for local campuses. You will collaborate on UI designs, Firebase integrations, and state management using Riverpod.',
                              'deadline': Timestamp.fromDate(DateTime.now().add(const Duration(days: 10))),
                              'status': 'open',
                              'createdAt': Timestamp.now(),
                              'founderId': user.userId,
                              'startupId': startup.startupId,
                            },
                            {
                              'title': 'UI/UX Designer',
                              'startupName': startup.name,
                              'startupSector': startup.sector ?? 'Tech',
                              'university': startup.university,
                              'requiredSkills': ['Figma', 'Prototyping', 'Adobe XD'],
                              'type': 'job',
                              'locationType': 'remote',
                              'compensationType': 'negotiable',
                              'compensationDetails': 'Equity option',
                              'description': 'Looking for a creative mind to lead our new visual design system. You will create wireframes, components, and high-fidelity prototype flows in Figma.',
                              'deadline': Timestamp.fromDate(DateTime.now().add(const Duration(days: 15))),
                              'status': 'open',
                              'createdAt': Timestamp.now(),
                              'founderId': user.userId,
                              'startupId': startup.startupId,
                            },
                            {
                              'title': 'Backend Engineer (Node)',
                              'startupName': startup.name,
                              'startupSector': startup.sector ?? 'Tech',
                              'university': startup.university,
                              'requiredSkills': ['Node.js', 'PostgreSQL', 'Docker', 'REST APIs'],
                              'type': 'job',
                              'locationType': 'on-site',
                              'compensationType': 'paid',
                              'compensationDetails': 'Rs 25,000',
                              'description': 'Scale our core payment APIs and databases. You will manage PostgreSQL query optimization, server deployments, and containerization.',
                              'deadline': Timestamp.fromDate(DateTime.now().add(const Duration(days: 5))),
                              'status': 'open',
                              'createdAt': Timestamp.now(),
                              'founderId': user.userId,
                              'startupId': startup.startupId,
                            }
                          ];

                          final createdListingIds = <String>[];
                          for (var i = 0; i < mockListings.length; i++) {
                            final doc = listingsCol.doc('seed-listing-${startup.startupId}-${i + 1}');
                            batch.set(doc, mockListings[i]);
                            createdListingIds.add(doc.id);
                          }

                          // 3. Seed Applications linked to the current founder's listings
                          final mockApps = [
                            {
                              'studentId': 'seed-student-1',
                              'listingId': 'seed-listing-${startup.startupId}-1',
                              'coverNote': 'Flutter development is my absolute passion! I have designed three modular dashboards and would love to join TechLab to build the smart classroom application.',
                              'status': 'pending',
                              'matchScore': 100,
                              'matchedSkills': ['Flutter', 'Dart', 'Firebase', 'Git'],
                              'missingSkills': <String>[],
                              'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 4))),
                              'startupId': startup.startupId,
                            },
                            {
                              'studentId': 'seed-student-2',
                              'listingId': 'seed-listing-${startup.startupId}-2',
                              'coverNote': 'Your product-led SaaS growth strategy looks excellent. I have designed interactive web prototypes and would love to lead visual layout layouts here.',
                              'status': 'shortlisted',
                              'matchScore': 100,
                              'matchedSkills': ['Figma', 'Prototyping', 'Adobe XD'],
                              'missingSkills': <String>[],
                              'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))),
                              'startupId': startup.startupId,
                            },
                            {
                              'studentId': 'seed-student-3',
                              'listingId': 'seed-listing-${startup.startupId}-3',
                              'coverNote': 'Backend Node query optimizer here. Ready to scale your payment systems and secure micro-transaction pipelines!',
                              'status': 'hired',
                              'matchScore': 75,
                              'matchedSkills': ['Node.js', 'PostgreSQL', 'Docker'],
                              'missingSkills': ['REST APIs'],
                              'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 3))),
                              'startupId': startup.startupId,
                            }
                          ];

                          for (var i = 0; i < mockApps.length; i++) {
                            final doc = appsCol.doc('seed-app-${startup.startupId}-${i + 1}');
                            batch.set(doc, mockApps[i]);
                          }

                          await batch.commit();

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('App Ecosystem & Applicants seeded successfully!'),
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

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FounderCreateEventScreen()),
                        );
                      },
                      child: const Text('Post New Event', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
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
          );
        },
      ),
    );
  }
}
