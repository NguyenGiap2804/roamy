import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/place.dart';
import '../../providers/category_provider.dart';
import '../../providers/place_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/category_filter_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/place_card.dart';
import '../../widgets/section_title.dart';
import '../add_place/add_place_screen.dart';
import '../place_detail/place_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaceProvider>().fetchPlaces();
      context.read<CategoryProvider>().fetchCategories();
    });
  }

  List<Place> _filteredPlaces(List<Place> places) {
    return places.where((place) {
      final matchesCategory =
          _selectedCategory == 'All' || place.category == _selectedCategory;
      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch =
          query.isEmpty ||
          place.name.toLowerCase().contains(query) ||
          place.address.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer2<PlaceProvider, CategoryProvider>(
        builder: (context, placeProvider, categoryProvider, _) {
          final categories = [
            'All',
            ...categoryProvider.categories.map((category) => category.name),
          ];
          final places = _filteredPlaces(placeProvider.places);

          return RefreshIndicator(
            onRefresh: () => placeProvider.fetchPlaces(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                96,
              ),
              children: [
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) {
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, Nguyên Giáp 👋',
                                style: AppTextStyles.headline,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Where do you want to go next?',
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
                        const SizedBox(width: 8),
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
                ),
                const SizedBox(height: 22),
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: const InputDecoration(
                    hintText: 'Search places...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return CategoryFilterChip(
                        label: category,
                        selected: category == _selectedCategory,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = category),
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemCount: categories.length,
                  ),
                ),
                const SizedBox(height: 24),
                const SectionTitle(
                  title: 'Saved places',
                  icon: Icons.bookmark_rounded,
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
                    title: 'Could not load places',
                    message: placeProvider.errorMessage!,
                  )
                else if (places.isEmpty)
                  const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No places found',
                    message: 'Try another search or category.',
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
                          if (context.mounted) {
                            await context.read<PlaceProvider>().fetchPlaces();
                          }
                        },
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlaceDetailScreen(place: place),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
