import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../founder/listings_screen.dart';
import '../founder/pipeline_screen.dart';
import '../founder/profile_screen.dart';
import '../shared/chats_list_screen.dart';

class FounderShell extends StatefulWidget {
  const FounderShell({super.key});

  @override
  State<FounderShell> createState() => _FounderShellState();
}

class _FounderShellState extends State<FounderShell> {
  int _currentIndex = 0;

  final List<Widget> _views = [
    const FounderListingsScreen(),
    const FounderPipelineScreen(),
    const ChatsListScreen(),
    const FounderProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _views,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.cardDark,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMutedLight,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work),
            label: 'Listings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Applicants',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            activeIcon: Icon(Icons.forum),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business_outlined),
            activeIcon: Icon(Icons.business),
            label: 'Startup',
          ),
        ],
      ),
    );
  }
}
