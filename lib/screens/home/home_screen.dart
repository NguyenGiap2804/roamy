import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/explore_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/explore_place_card.dart';
import '../../widgets/nearby_detail_sheet.dart';
import '../../widgets/popular_place_card.dart';
import '../../widgets/section_title.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final exploreProvider = context.read<ExploreProvider>();
      if (!exploreProvider.initialLoadDone) {
        exploreProvider.fetchNearby();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    context.read<ExploreProvider>().refreshLocationIfStale();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<ExploreProvider>(
        builder: (context, exploreProvider, _) {
          final isSearchActive = exploreProvider.hasSearchQuery;

          return RefreshIndicator(
            onRefresh: () async {
              _searchController.clear();
              await exploreProvider.refresh();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                96,
              ),
              children: [
                // ── Greeting ──
                _GreetingHeader(exploreProvider: exploreProvider),
                const SizedBox(height: 22),

                // ── Search bar ──
                TextField(
                  controller: _searchController,
                  onChanged: (value) => exploreProvider.search(value),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm: cafe, phở, khách sạn...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: isSearchActive
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              exploreProvider.clearSearch();
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Category filter chips ──
                if (!isSearchActive &&
                    exploreProvider.availableCategories.length > 1)
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: exploreProvider.availableCategories.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = exploreProvider.availableCategories[index];
                        final isSelected =
                            cat == exploreProvider.selectedCategory;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (_) =>
                              exploreProvider.changeCategory(cat),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : null,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 20),

                // ── Search results mode ──
                if (isSearchActive) ...[
                  _SearchResultsSection(exploreProvider: exploreProvider),
                ]
                // ── Loading state ──
                else if (exploreProvider.isLoading &&
                    exploreProvider.nearbyPlaces.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Đang tìm địa điểm gần bạn...',
                            style: AppTextStyles.subtitle,
                          ),
                        ],
                      ),
                    ),
                  )
                // ── Error state ──
                else if (exploreProvider.errorMessage != null &&
                    exploreProvider.nearbyPlaces.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 36),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 48,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          exploreProvider.errorMessage!,
                          style: AppTextStyles.subtitle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => exploreProvider.refresh(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                // ── Default: Nearby + Popular + Saved ──
                else ...[
                  // 📍 Nearby section
                  if (exploreProvider.nearbyPlaces.isNotEmpty) ...[
                    const SectionTitle(
                      title: 'Gần bạn',
                      icon: Icons.near_me_rounded,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 230,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: exploreProvider.nearbyPlaces.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final place = exploreProvider.nearbyPlaces[index];
                          return ExplorePlaceCard.fromNearby(
                            place: place,
                            distanceText: exploreProvider.getDistanceString(
                              place,
                            ),
                            onTap: () => NearbyDetailSheet.show(context, place),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // 🔥 Popular section (vertical list)
                  if (exploreProvider.popularPlaces.isNotEmpty) ...[
                    const SectionTitle(
                      title: 'Phổ biến nhất',
                      icon: Icons.local_fire_department_rounded,
                    ),
                    const SizedBox(height: 14),
                    ...List.generate(exploreProvider.popularPlaces.length, (
                      index,
                    ) {
                      final place = exploreProvider.popularPlaces[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PopularPlaceCard(
                          place: place,
                          index: index,
                          onTap: () => NearbyDetailSheet.show(context, place),
                        ),
                      );
                    }),
                  ],

                  // Empty state
                  if (exploreProvider.nearbyPlaces.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 36),
                      child: Column(
                        children: [
                          Icon(
                            Icons.explore_off_rounded,
                            size: 48,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Không tìm thấy địa điểm nào trong khu vực này.',
                            style: AppTextStyles.subtitle,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Search Results Section ──

class _SearchResultsSection extends StatelessWidget {
  const _SearchResultsSection({required this.exploreProvider});

  final ExploreProvider exploreProvider;

  @override
  Widget build(BuildContext context) {
    if (exploreProvider.isSearching) {
      return const Padding(
        padding: EdgeInsets.only(top: 36),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (exploreProvider.searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 36),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Không tìm thấy kết quả cho "${exploreProvider.searchQuery}"',
              style: AppTextStyles.subtitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: 'Kết quả tìm kiếm (${exploreProvider.searchResults.length})',
          icon: Icons.search_rounded,
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 230,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: exploreProvider.searchResults.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final place = exploreProvider.searchResults[index];
              return ExplorePlaceCard.fromNearby(
                place: place,
                distanceText: exploreProvider.getDistanceString(place),
                onTap: () => NearbyDetailSheet.show(context, place),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Greeting Header ──

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.exploreProvider});

  final ExploreProvider exploreProvider;

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Khám phá hôm nay 🌏', style: AppTextStyles.headline),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        exploreProvider.isUsingFallbackLocation
                            ? Icons.location_off_rounded
                            : Icons.location_on_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        exploreProvider.cityName,
                        style: AppTextStyles.subtitle.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            CircleAvatar(
              radius: 24,
              backgroundColor: themeProvider.isDarkMode
                  ? Colors.white10
                  : AppColors.primarySoft,
              child: Text(
                'NG',
                style: AppTextStyles.caption.copyWith(
                  color: themeProvider.isDarkMode
                      ? Colors.white
                      : AppColors.primaryDark,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
