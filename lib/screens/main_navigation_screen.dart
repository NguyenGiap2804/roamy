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
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Lịch trình',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Danh mục',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Tôi',
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
              label: const Text('Thêm địa điểm'),
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
          Text('Xin chào, Nguyên Giáp', style: AppTextStyles.headline),
          const SizedBox(height: 8),
          const Text(
            'Lên kế hoạch cho chuyến đi tiếp theo cùng Roamy',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.explore_rounded, color: AppColors.primary, size: 34),
                SizedBox(height: 14),
                Text(
                  'Roamy giúp bạn lưu giữ các địa điểm, ghi chú và kế hoạch tương lai trong một không gian tối giản.',
                ),
                SizedBox(height: 12),
                Text('Đã kết nối với hệ thống Roamy Backend.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
