import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/startup_provider.dart';
import '../../providers/skills_config_provider.dart';
import '../../theme/app_colors.dart';
import '../../components/shared/skill_chip.dart';
import '../../services/ai_service.dart';

class FounderPostListingScreen extends ConsumerStatefulWidget {
  const FounderPostListingScreen({super.key});

  @override
  ConsumerState<FounderPostListingScreen> createState() => _FounderPostListingScreenState();
}

class _FounderPostListingScreenState extends ConsumerState<FounderPostListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _compDetailsController = TextEditingController();

  String _selectedType = 'internship'; // job, internship, cofounding, partnership
  String _selectedLocation = 'remote'; // remote, on-site, hybrid
  String _selectedCompType = 'paid'; // paid, equity, unpaid, negotiable
  DateTime _selectedDeadline = DateTime.now().add(const Duration(days: 14));
  final Set<String> _requiredSkills = {};
  bool _isLoading = false;
  bool _isCheckingQuality = false;
  Map<String, dynamic>? _qualityResult;

  Future<void> _selectDeadline(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null && picked != _selectedDeadline) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
  }

  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate()) return;
    if (_requiredSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 required skill.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authUser = ref.read(currentUserProvider);
      final startup = ref.read(startupStreamProvider).value;
      if (authUser == null || startup == null) throw Exception('Founder startup profiles not hydrated.');

      final listingsRef = FirebaseFirestore.instance.collection('listings').doc();
      
      final listingData = {
        'founderId': authUser.uid,
        'startupId': startup.startupId,
        'startupName': startup.name,
        'startupSector': startup.sector,
        'university': startup.university,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'type': _selectedType,
        'locationType': _selectedLocation,
        'compensationType': _selectedCompType,
        'compensationDetails': _compDetailsController.text.trim().isEmpty ? null : _compDetailsController.text.trim(),
        'requiredSkills': _requiredSkills.toList(),
        'deadline': Timestamp.fromDate(_selectedDeadline),
        'status': 'open',
        'createdAt': Timestamp.now(),
      };

      await listingsRef.set(listingData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Role posted successfully!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to post role: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skillsAsync = ref.watch(skillsConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post New Role'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title input
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Role Title',
                  hintText: 'e.g. Flutter Developer, Product Lead',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 20),

              // Description input
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Role Description',
                  hintText: 'Detail requirements, expectations, and startup project context...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) => v!.isEmpty ? 'Please enter a description' : null,
              ),
              const SizedBox(height: 24),

              // Type & Location Grid
              Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Role Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'job', child: Text('Job')),
                        DropdownMenuItem(value: 'internship', child: Text('Internship')),
                        DropdownMenuItem(value: 'cofounding', child: Text('Co-founder')),
                        DropdownMenuItem(value: 'partnership', child: Text('Partnership')),
                      ],
                      onChanged: (v) => setState(() => _selectedType = v!),
                    ),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedLocation,
                      decoration: const InputDecoration(
                        labelText: 'Location Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'remote', child: Text('Remote')),
                        DropdownMenuItem(value: 'on-site', child: Text('On-Site')),
                        DropdownMenuItem(value: 'hybrid', child: Text('Hybrid')),
                      ],
                      onChanged: (v) => setState(() => _selectedLocation = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Compensation Grid
              Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCompType,
                      decoration: const InputDecoration(
                        labelText: 'Compensation',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'paid', child: Text('Paid')),
                        DropdownMenuItem(value: 'equity', child: Text('Equity')),
                        DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                        DropdownMenuItem(value: 'negotiable', child: Text('Negotiable')),
                      ],
                      onChanged: (v) => setState(() => _selectedCompType = v!),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _compDetailsController,
                      decoration: const InputDecoration(
                        labelText: 'Details (Optional)',
                        hintText: 'e.g. Rs 15k, 2% Equity',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Deadline Picker
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.dividerDark),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Application Deadline', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMutedLight)),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedDeadline.day}/${_selectedDeadline.month}/${_selectedDeadline.year}',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today, color: AppColors.primary),
                      onPressed: () => _selectDeadline(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Skills Taxonomy Selection
              Text('Required Skills', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('Select the exact skillset student profiles will match against:', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMutedLight)),
              const SizedBox(height: 16),
              
              skillsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Error loading skills: $err'),
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
                              final isSelected = _requiredSkills.contains(skill);
                              return SkillChip(
                                label: skill,
                                variant: isSelected ? SkillChipVariant.selected : SkillChipVariant.neutral,
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _requiredSkills.remove(skill);
                                    } else {
                                      _requiredSkills.add(skill);
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
              ),
              const SizedBox(height: 32),

              OutlinedButton.icon(
                onPressed: _isCheckingQuality
                    ? null
                    : () async {
                        if (_titleController.text.trim().isEmpty || _descriptionController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill in title and description first'),
                              backgroundColor: AppColors.errorRed,
                            ),
                          );
                          return;
                        }

                        setState(() => _isCheckingQuality = true);
                        try {
                          final result = await AIService.checkListingQuality(
                            title: _titleController.text.trim(),
                            type: _selectedType,
                            description: _descriptionController.text.trim(),
                            requiredSkills: _requiredSkills.toList(),
                            compensationType: _selectedCompType,
                            locationType: _selectedLocation,
                            deadline: _selectedDeadline,
                          );
                          if (result != null) {
                            setState(() {
                              _qualityResult = result;
                            });
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Quality check unavailable right now'),
                                  backgroundColor: AppColors.errorRed,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Quality check failed: $e'),
                                backgroundColor: AppColors.errorRed,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isCheckingQuality = false);
                          }
                        }
                      },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: _isCheckingQuality
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Icon(Icons.verified_user_outlined),
                label: Text(_isCheckingQuality ? 'Checking Quality...' : 'Check listing quality'),
              ),

              if (_qualityResult != null) ...[
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: () {
                                  final score = _qualityResult!['qualityScore'] as int? ?? 0;
                                  if (score >= 80) return AppColors.successGreen.withOpacity(0.15);
                                  if (score >= 50) return Colors.amber.withOpacity(0.15);
                                  return AppColors.errorRed.withOpacity(0.15);
                                }(),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${_qualityResult!['qualityScore'] ?? 0}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: () {
                                    final score = _qualityResult!['qualityScore'] as int? ?? 0;
                                    if (score >= 80) return AppColors.successGreen;
                                    if (score >= 50) return Colors.amber;
                                    return AppColors.errorRed;
                                  }(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Listing Quality Score',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 24, color: AppColors.dividerDark),

                        // Issues
                        if ((_qualityResult!['issues'] as List? ?? []).isNotEmpty) ...[
                          Text('Issues Found', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...((_qualityResult!['issues'] as List? ?? []).map((issue) {
                            final severity = issue['severity'] as String? ?? 'low';
                            final msg = issue['message'] as String? ?? '';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    severity == 'high'
                                        ? Icons.error
                                        : severity == 'medium'
                                            ? Icons.warning
                                            : Icons.info,
                                    color: severity == 'high'
                                        ? AppColors.errorRed
                                        : severity == 'medium'
                                            ? Colors.amber
                                            : Colors.blue,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      msg,
                                      style: const TextStyle(color: AppColors.textLight, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })),
                          const SizedBox(height: 16),
                        ],

                        // Suggested Title
                        if (_qualityResult!['suggestedTitle'] != null &&
                            _qualityResult!['suggestedTitle'].toString().toLowerCase().trim() !=
                                _titleController.text.toLowerCase().trim()) ...[
                          Text('Suggested Title', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
                                    _qualityResult!['suggestedTitle'] ?? '',
                                    style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                TextButton(
                                  child: const Text('Use this'),
                                  onPressed: () {
                                    _titleController.text = _qualityResult!['suggestedTitle'] ?? '';
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        Align(
                          alignment: Alignment.bottomRight,
                          child: TextButton(
                            child: const Text('Dismiss', style: TextStyle(color: AppColors.errorRed)),
                            onPressed: () {
                              setState(() {
                                _qualityResult = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _submitListing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(56),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.textDark, strokeWidth: 2))
                    : const Text('Post Role'),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
