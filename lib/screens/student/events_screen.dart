import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/events_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../components/shared/initials_avatar.dart';
import 'event_detail_screen.dart';

class StudentEventsScreen extends ConsumerStatefulWidget {
  const StudentEventsScreen({super.key});

  @override
  ConsumerState<StudentEventsScreen> createState() => _StudentEventsScreenState();
}

class _StudentEventsScreenState extends ConsumerState<StudentEventsScreen> {
  String _activeCategory = 'All';

  final List<String> _categories = [
    'All',
    'Workshop',
    'Seminar',
    'Networking',
    'Hackathon'
  ];

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'workshop': return AppColors.primary;
      case 'seminar': return Colors.teal;
      case 'hackathon': return AppColors.errorRed;
      case 'networking': return AppColors.successGreen;
      default: return AppColors.dividerDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsStreamProvider);
    final userAsync = ref.watch(userStreamProvider);
    final user = userAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Events'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            height: 60,
            padding: const EdgeInsets.only(bottom: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _activeCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _activeCategory = category;
                      });
                    },
                    selectedColor: AppColors.primary,
                    checkmarkColor: AppColors.textDark,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.textDark : AppColors.textLight,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: AppColors.cardDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.dividerDark,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.errorRed))),
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event_busy_outlined, size: 64, color: AppColors.textMutedLight),
                    const SizedBox(height: 16),
                    Text(
                      'No events listed yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check back later for seminars, hackathons, and networking sessions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMutedLight, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          // Filter by category
          final filteredEvents = _activeCategory == 'All'
              ? events
              : events.where((e) => e.type.toLowerCase() == _activeCategory.toLowerCase()).toList();

          // Split events into Upcoming Carousel and All list
          final now = DateTime.now();
          final upcomingEvents = filteredEvents.where((e) => e.dateTime.isAfter(now)).toList();
          final otherEvents = filteredEvents.where((e) => e.dateTime.isBefore(now) || upcomingEvents.contains(e) == false).toList();

          if (filteredEvents.isEmpty) {
            return Center(
              child: Text(
                'No $_activeCategory events found.',
                style: const TextStyle(color: AppColors.textMutedLight),
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Upcoming Horizontal Carousel ─────────────────────
                if (upcomingEvents.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: Text(
                      'Upcoming Events 🚀',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textLight,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 230,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: upcomingEvents.length,
                      itemBuilder: (context, index) {
                        final event = upcomingEvents[index];
                        final typeColor = _getTypeColor(event.type);
                        final hasRsvpd = user != null && event.attendees.contains(user.userId);

                        return Container(
                          width: 300,
                          margin: const EdgeInsets.only(right: 16, bottom: 8),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                              side: const BorderSide(color: AppColors.dividerDark),
                            ),
                            child: InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EventDetailScreen(event: event),
                                ),
                              ),
                              borderRadius: BorderRadius.circular(24),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: typeColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            event.type.toUpperCase(),
                                            style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        if (hasRsvpd)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.successGreen.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.check, size: 10, color: AppColors.successGreen),
                                                SizedBox(width: 2),
                                                Text('RSVP\'d', style: TextStyle(color: AppColors.successGreen, fontSize: 9, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: Text(
                                        event.title,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.3),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMutedLight),
                                        const SizedBox(width: 6),
                                        Text(
                                          DateFormat('MMM d · h:mm a').format(event.dateTime),
                                          style: const TextStyle(color: AppColors.textMutedLight, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(event.isOnline ? Icons.laptop_outlined : Icons.location_on_outlined, size: 14, color: AppColors.textMutedLight),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            event.location,
                                            style: const TextStyle(color: AppColors.textMutedLight, fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // ─── All / Past Events List ──────────────────────────
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Text(
                    'All Events',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textLight,
                    ),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: otherEvents.isNotEmpty ? otherEvents.length : upcomingEvents.length,
                  itemBuilder: (context, index) {
                    final event = otherEvents.isNotEmpty ? otherEvents[index] : upcomingEvents[index];
                    final typeColor = _getTypeColor(event.type);
                    final hasRsvpd = user != null && event.attendees.contains(user.userId);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EventDetailScreen(event: event),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              // Startup Logo
                              InitialsAvatar(
                                name: event.startupName ?? 'S',
                                radius: 24,
                                imageUrl: event.logoUrl,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: typeColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            event.type.toUpperCase(),
                                            style: TextStyle(color: typeColor, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (hasRsvpd)
                                          const Text(
                                            '✓ Registered',
                                            style: TextStyle(color: AppColors.successGreen, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      event.title,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${DateFormat('MMM d').format(event.dateTime)} · ${event.location}',
                                      style: const TextStyle(color: AppColors.textMutedLight, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMutedLight),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
