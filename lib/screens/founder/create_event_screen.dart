import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../providers/events_provider.dart';
import '../../providers/startup_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';

class FounderCreateEventScreen extends ConsumerStatefulWidget {
  const FounderCreateEventScreen({super.key});

  @override
  ConsumerState<FounderCreateEventScreen> createState() => _FounderCreateEventScreenState();
}

class _FounderCreateEventScreenState extends ConsumerState<FounderCreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _meetingUrlController = TextEditingController();
  final _speakerController = TextEditingController();

  String _selectedType = 'workshop';
  DateTime _selectedDateTime = DateTime.now().add(const Duration(days: 1));
  bool _isOnline = false;
  final List<String> _speakers = [];
  bool _isSaving = false;

  final List<String> _types = ['workshop', 'seminar', 'networking', 'hackathon'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _meetingUrlController.dispose();
    _speakerController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _addSpeaker() {
    final name = _speakerController.text.trim();
    if (name.isNotEmpty) {
      setState(() {
        _speakers.add(name);
        _speakerController.clear();
      });
    }
  }

  void _removeSpeaker(int index) {
    setState(() {
      _speakers.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final startup = ref.read(startupStreamProvider).value;
    final user = ref.read(userStreamProvider).value;

    if (startup == null || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile not fully loaded yet.'), backgroundColor: AppColors.errorRed),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('events').doc();
      final event = EventModel(
        eventId: docRef.id,
        startupId: startup.startupId,
        founderId: user.userId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        dateTime: _selectedDateTime,
        location: _locationController.text.trim(),
        isOnline: _isOnline,
        meetingUrl: _isOnline ? _meetingUrlController.text.trim() : null,
        speakers: _speakers,
        attendees: [],
        createdAt: DateTime.now(),
        startupName: startup.name,
        logoUrl: startup.logoUrl,
      );

      await ref.read(eventsServiceProvider).createEvent(event);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event posted successfully! 📅'), backgroundColor: AppColors.successGreen),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post event: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDateTime = DateFormat('EEEE, MMMM d, yyyy · h:mm a').format(_selectedDateTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post New Event'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Event Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 20),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Event Description',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(Icons.description_outlined),
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a description' : null,
              ),
              const SizedBox(height: 24),

              // Event Type Choice
              const Text(
                'Event Type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textLight),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _types.map((type) {
                  final isSelected = _selectedType == type;
                  return ChoiceChip(
                    label: Text(type.toUpperCase()),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedType = type);
                      }
                    },
                    selectedColor: AppColors.primary,
                    checkmarkColor: AppColors.textDark,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.textDark : AppColors.textLight,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Date & Time Picker Row
              const Text(
                'Date & Time',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textLight),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDateTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.dividerDark),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          formattedDateTime,
                          style: const TextStyle(color: AppColors.textLight, fontSize: 15),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: AppColors.textMutedLight),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Online / Physical Toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'This is an online event',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textLight),
                ),
                subtitle: const Text('Provide video meeting links directly to attendees'),
                value: _isOnline,
                onChanged: (val) {
                  setState(() {
                    _isOnline = val;
                  });
                },
                activeColor: AppColors.primary,
              ),
              const SizedBox(height: 16),

              // Location or Meeting URL
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: _isOnline ? 'Online platform (e.g. Zoom, Google Meet)' : 'Physical Venue Location',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(_isOnline ? Icons.computer : Icons.location_on),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please specify location platform/venue' : null,
              ),
              const SizedBox(height: 20),

              if (_isOnline) ...[
                TextFormField(
                  controller: _meetingUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Meeting URL Link (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Speakers Array Input
              const Text(
                'Speakers',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textLight),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _speakerController,
                      decoration: const InputDecoration(
                        labelText: 'Add speaker name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _addSpeaker,
                    icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 36),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_speakers.length, (index) {
                  return Chip(
                    label: Text(_speakers[index]),
                    onDeleted: () => _removeSpeaker(index),
                    deleteIconColor: AppColors.errorRed,
                    backgroundColor: AppColors.cardDark,
                    side: const BorderSide(color: AppColors.dividerDark),
                  );
                }),
              ),
              const SizedBox(height: 48),

              // Submit Button
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(56),
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.textDark, strokeWidth: 2))
                    : const Text(
                        'Post Event',
                        style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
