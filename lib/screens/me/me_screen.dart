import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/place.dart';
import '../../providers/category_provider.dart';
import '../../providers/place_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/place_card.dart';
import '../../widgets/section_title.dart';
import '../add_place/add_place_screen.dart';
import '../place_detail/place_detail_screen.dart';
import '../visit_history/visit_history_screen.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaceProvider>().fetchPlaces();
    });
  }

  List<Place> _filteredPlaces(List<Place> places) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return places;
    return places.where((place) {
      return place.name.toLowerCase().contains(query) ||
          place.address.toLowerCase().contains(query) ||
          place.category.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer3<PlaceProvider, CategoryProvider, ThemeProvider>(
        builder: (context, placeProvider, categoryProvider, themeProvider, _) {
          final places = _filteredPlaces(placeProvider.places);

          return RefreshIndicator(
            onRefresh: () => placeProvider.fetchPlaces(),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: themeProvider.isDarkMode
                          ? Colors.white10
                          : AppColors.primarySoft,
                      child: Text(
                        'NG',
                        style: AppTextStyles.title.copyWith(
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nguyên Giáp',
                            style: AppTextStyles.headline.copyWith(
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Khám phá thế giới cùng Roamy',
                            style: AppTextStyles.subtitle,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => themeProvider.toggleTheme(),
                      icon: Icon(
                        themeProvider.isDarkMode
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: themeProvider.isDarkMode
                            ? Colors.amber
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Quick stats
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.place_rounded,
                        value: '${placeProvider.places.length}',
                        label: 'Địa điểm',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.category_rounded,
                        value: '${categoryProvider.categories.length}',
                        label: 'Danh mục',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.star_rounded,
                        value: _averageRating(placeProvider.places),
                        label: 'Đánh giá TB',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Quick links
                _QuickLinkTile(
                  icon: Icons.history_rounded,
                  label: 'Lịch sử đã đi',
                  subtitle: 'Xem những nơi bạn đã ghé thăm',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const VisitHistoryScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Saved places section
                const SectionTitle(
                  title: 'Địa điểm đã lưu',
                  icon: Icons.bookmark_rounded,
                ),
                if (placeProvider.hasPendingSync) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Đang đồng bộ thay đổi...',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Search within saved places
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: const InputDecoration(
                    hintText: 'Tìm trong địa điểm đã lưu...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 14),

                if (placeProvider.isLoading && placeProvider.places.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 36),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (placeProvider.errorMessage != null)
                  EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Không thể tải địa điểm',
                    message: placeProvider.errorMessage!,
                  )
                else if (places.isEmpty)
                  const EmptyState(
                    icon: Icons.bookmark_border_rounded,
                    title: 'Chưa có địa điểm nào',
                    message: 'Thêm địa điểm từ trang chủ để bắt đầu.',
                  )
                else
                  ...places.map(
                    (place) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: PlaceCard(
                        place: place,
                        onUpdate: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddPlaceScreen(place: place),
                            ),
                          );
                        },
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  PlaceDetailScreen(place: place),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 24,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _averageRating(List<Place> places) {
    if (places.isEmpty) return '-';
    final sum = places.fold(0.0, (total, place) => total + place.rating);
    return (sum / places.length).toStringAsFixed(1);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.title.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.title.copyWith(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
