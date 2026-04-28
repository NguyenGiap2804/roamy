import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/constants/app_text_styles.dart';
import '../providers/schedule_provider.dart';
import 'add_place/add_place_screen.dart';
import 'calendar/calendar_screen.dart';
import 'categories/categories_screen.dart';
import 'home/home_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    const HomeScreen(),
    const CalendarScreen(),
    const CategoriesScreen(),
    const _MeScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().resyncUpcomingNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Me',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddPlaceScreen()),
                );
              },
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('Add place'),
            )
          : null,
    );
  }
}

class _MeScreen extends StatelessWidget {
  const _MeScreen();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text('Hello, Nguyên Giáp', style: AppTextStyles.headline),
          const SizedBox(height: 8),
          const Text(
            'Plan your next trip with Roamy',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.explore_rounded, color: AppColors.primary, size: 34),
                SizedBox(height: 14),
                Text(
                  'Roamy keeps your saved places, notes, and future plans in one calm workspace.',
                ),
                SizedBox(height: 12),
                Text('Connected to Roamy Backend with local API data.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
