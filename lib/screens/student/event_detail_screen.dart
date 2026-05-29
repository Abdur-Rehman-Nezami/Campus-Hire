import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/event_model.dart';
import '../../models/user_model.dart';
import '../../providers/events_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../components/shared/initials_avatar.dart';
import 'startup_profile_screen.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final EventModel event;

  const EventDetailScreen({super.key, required this.event});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _isProcessing = false;

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'workshop': return AppColors.primary;
      case 'seminar': return Colors.teal;
      case 'hackathon': return AppColors.errorRed;
      case 'networking': return AppColors.successGreen;
      default: return AppColors.dividerDark;
    }
  }

  Future<void> _launchMeetingUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open meeting link.'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Future<void> _toggleRSVP(bool hasRsvpd, UserModel user) async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(eventsServiceProvider).rsvpToEvent(
        eventId: widget.event.eventId,
        userId: user.userId,
        studentName: user.name,
        eventTitle: widget.event.title,
        founderId: widget.event.founderId,
        isRegistering: !hasRsvpd,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!hasRsvpd ? 'Successfully RSVP\'d! 🎉' : 'RSVP cancelled.'),
            backgroundColor: !hasRsvpd ? AppColors.successGreen : AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update RSVP: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userStreamProvider);
    final eventsAsync = ref.watch(eventsStreamProvider);
    
    // Watch this specific event reactively from stream if possible
    final currentEvent = eventsAsync.value?.firstWhere(
      (e) => e.eventId == widget.event.eventId,
      orElse: () => widget.event,
    ) ?? widget.event;

    final typeColor = _getTypeColor(currentEvent.type);
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(currentEvent.dateTime);
    final formattedTime = DateFormat('jm').format(currentEvent.dateTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header Category Badge ──────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: typeColor.withValues(alpha: 0.25)),
              ),
              child: Text(
                currentEvent.type.toUpperCase(),
                style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(currentEvent.title, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 24),

            // ─── Organized By (Startup card) ─────────────────────
            GestureDetector(
              onTap: () {
                if (currentEvent.startupId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StartupPublicProfileScreen(startupId: currentEvent.startupId),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.dividerDark),
                ),
                child: Row(
                  children: [
                    InitialsAvatar(
                      name: currentEvent.startupName ?? 'S',
                      radius: 24,
                      imageUrl: currentEvent.logoUrl,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Organized by',
                            style: TextStyle(color: AppColors.textMutedLight, fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                currentEvent.startupName ?? 'Startup',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.textMutedLight),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── Time & Location Card ───────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.dividerDark),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formattedDate, style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(formattedTime, style: const TextStyle(color: AppColors.textMutedLight, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Divider(color: AppColors.dividerDark, height: 1),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        currentEvent.isOnline ? Icons.laptop_outlined : Icons.location_on_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentEvent.isOnline ? 'Online Event' : 'Physical Location',
                              style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(currentEvent.location, style: const TextStyle(color: AppColors.textMutedLight, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ─── Event Description ──────────────────────────────
            Text('About the Event', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              currentEvent.description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.6,
                color: AppColors.textMutedLight,
              ),
            ),
            const SizedBox(height: 32),

            // ─── Speakers Section ────────────────────────────────
            if (currentEvent.speakers.isNotEmpty) ...[
              Text('Speakers', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              ...currentEvent.speakers.map((speaker) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: typeColor.withValues(alpha: 0.15),
                      child: Text(
                        speaker[0].toUpperCase(),
                        style: TextStyle(color: typeColor, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      speaker,
                      style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 32),
            ],

            // ─── Attendees preview bubbles ───────────────────────
            _AttendeesSection(attendees: currentEvent.attendees),

            // Extra space
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          color: AppColors.scaffoldBackground,
          border: Border(top: BorderSide(color: AppColors.dividerDark)),
        ),
        child: SafeArea(
          child: userAsync.when(
            loading: () => const SizedBox(height: 56, child: Center(child: CircularProgressIndicator())),
            error: (err, _) => Text('Error: $err'),
            data: (user) {
              if (user == null || user.role != 'student') {
                return const SizedBox.shrink();
              }

              final hasRsvpd = currentEvent.attendees.contains(user.userId);

              return Row(
                children: [
                  if (currentEvent.isOnline && currentEvent.meetingUrl != null && currentEvent.meetingUrl!.isNotEmpty && hasRsvpd) ...[
                    OutlinedButton(
                      onPressed: () => _launchMeetingUrl(currentEvent.meetingUrl!),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(56, 56),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Icon(Icons.videocam_outlined, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : () => _toggleRSVP(hasRsvpd, user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasRsvpd ? AppColors.dividerDark : AppColors.primary,
                        minimumSize: const Size.fromHeight(56),
                      ),
                      child: _isProcessing
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.textDark, strokeWidth: 2))
                          : Text(
                              hasRsvpd ? 'Cancel RSVP' : 'Register Now',
                              style: TextStyle(
                                color: hasRsvpd ? AppColors.textMutedLight : AppColors.textDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AttendeesSection extends StatelessWidget {
  final List<String> attendees;

  const _AttendeesSection({required this.attendees});

  @override
  Widget build(BuildContext context) {
    if (attendees.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attendees (${attendees.length})', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        FutureBuilder<QuerySnapshot>(
          // Fetch users matching UIDs in attendees array (limit 5 for performance and stack UI)
          future: FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: attendees.take(10).toList())
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 40,
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }

            final docs = snapshot.data!.docs;
            final users = docs.map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();

            return Row(
              children: [
                SizedBox(
                  height: 40,
                  width: (users.length * 28.0) + 12.0,
                  child: Stack(
                    children: List.generate(users.length, (index) {
                      final u = users[index];
                      return Positioned(
                        left: index * 26.0,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.scaffoldBackground, width: 2),
                          ),
                          child: InitialsAvatar(
                            name: u.name,
                            radius: 18,
                            imageUrl: u.profilePhotoUrl,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    attendees.length == 1
                        ? '${users.first.name} is attending'
                        : attendees.length == 2
                            ? '${users[0].name} and ${users[1].name} are attending'
                            : '${users[0].name}, ${users[1].name} and ${attendees.length - 2} others attending',
                    style: const TextStyle(color: AppColors.textMutedLight, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
