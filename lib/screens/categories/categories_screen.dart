import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/category.dart';
import '../../providers/category_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_button.dart';
import '../../core/utils/snackbar_helper.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().fetchCategories();
    });
  }

  void _showAddCategoryDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thêm danh mục'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Tên danh mục'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              final categoryName = controller.text.trim();
              if (categoryName.isEmpty) return;

              final provider = context.read<CategoryProvider>();

              try {
                await provider.addCategory(categoryName);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  SnackBarHelper.showSuccess(
                    context,
                    'Thêm danh mục thành công',
                  );
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  SnackBarHelper.showError(context, error.toString());
                }
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<CategoryProvider>(
        builder: (context, categoryProvider, _) {
          return RefreshIndicator(
            onRefresh: categoryProvider.fetchCategories,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Danh mục', style: AppTextStyles.headline),
                          const SizedBox(height: 8),
                          const Text(
                            'Sắp xếp địa điểm theo nhu cầu của bạn.',
                            style: AppTextStyles.subtitle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    PrimaryButton(
                      label: 'Thêm',
                      icon: Icons.add_rounded,
                      expanded: false,
                      onPressed: () => _showAddCategoryDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (categoryProvider.isLoading &&
                    categoryProvider.categories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 36),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (categoryProvider.errorMessage != null)
                  EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Không thể tải danh mục',
                    message: categoryProvider.errorMessage!,
                  )
                else if (categoryProvider.categories.isEmpty)
                  const EmptyState(
                    icon: Icons.category_outlined,
                    title: 'Chưa có danh mục nào',
                    message: 'Danh mục từ hệ thống sẽ hiển thị tại đây.',
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: categoryProvider.categories.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 190,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 1.08,
                        ),
                    itemBuilder: (context, index) => _CategoryCard(
                      category: categoryProvider.categories[index],
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

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(category.iconData, color: AppColors.primary),
          ),
          const Spacer(),
          Text(
            category.name,
            style: AppTextStyles.title.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            '${category.placeCount} địa điểm đã lưu',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
