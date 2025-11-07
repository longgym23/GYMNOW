import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gym_now/models/meal_plan_template_model.dart';
import 'package:gym_now/screens/meal_plan_detail_screen.dart';

class MealPlanTemplatesScreen extends StatefulWidget {
  const MealPlanTemplatesScreen({Key? key}) : super(key: key);

  @override
  State<MealPlanTemplatesScreen> createState() =>
      _MealPlanTemplatesScreenState();
}

class _MealPlanTemplatesScreenState extends State<MealPlanTemplatesScreen> {
  MealPlanCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Category filter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'Tất cả',
                  _selectedCategory == null,
                  () => setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Giảm cân',
                  _selectedCategory == MealPlanCategory.loseWeight,
                  () => setState(
                    () => _selectedCategory = MealPlanCategory.loseWeight,
                  ),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Giữ dáng',
                  _selectedCategory == MealPlanCategory.maintainWeight,
                  () => setState(
                    () => _selectedCategory = MealPlanCategory.maintainWeight,
                  ),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Tăng cân',
                  _selectedCategory == MealPlanCategory.gainWeight,
                  () => setState(
                    () => _selectedCategory = MealPlanCategory.gainWeight,
                  ),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Tăng cơ',
                  _selectedCategory == MealPlanCategory.gainMuscle,
                  () => setState(
                    () => _selectedCategory = MealPlanCategory.gainMuscle,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Meal plan list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('mealPlanTemplates')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 64,
                        color: Colors.white38,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Chưa có thực đơn nào',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Vui lòng import CSV từ menu Import',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                );
              }

              // Filter in memory to avoid Firestore index requirement
              final allTemplates = snapshot.data!.docs
                  .map((doc) => MealPlanTemplate.fromDoc(doc))
                  .toList();

              final filteredTemplates = _selectedCategory == null
                  ? allTemplates
                  : allTemplates
                        .where(
                          (template) => template.category == _selectedCategory,
                        )
                        .toList();

              if (filteredTemplates.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 64,
                        color: Colors.white38,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Chưa có thực đơn nào',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Thực đơn đang phát triển',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredTemplates.length,
                itemBuilder: (context, index) {
                  final template = filteredTemplates[index];
                  return _buildMealPlanCard(template);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : const Color(0xFF2A3B4F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.white24,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 18, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealPlanCard(MealPlanTemplate template) {
    final mealCount = template.meals.length;
    final calRange =
        '${(template.targetCalories * 0.95).toStringAsFixed(0)} - ${(template.targetCalories * 1.05).toStringAsFixed(0)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MealPlanDetailScreen(template: template),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getCategoryColor(template.category).withOpacity(0.8),
                    _getCategoryColor(template.category).withOpacity(0.4),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.restaurant_menu,
                      size: 80,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 3,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$calRange cal / ngày',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            shadows: [
                              const Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 2,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTag('${mealCount} bữa/ngày', Colors.blueAccent),
                      _buildTag('7 ngày', Colors.greenAccent),
                      if (template.category == MealPlanCategory.loseWeight)
                        _buildTag(
                          'Ít tinh bột - Tăng đạm',
                          Colors.orangeAccent,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getCategoryColor(MealPlanCategory category) {
    switch (category) {
      case MealPlanCategory.loseWeight:
        return Colors.orange;
      case MealPlanCategory.maintainWeight:
        return Colors.green;
      case MealPlanCategory.gainWeight:
        return Colors.blue;
      case MealPlanCategory.gainMuscle:
        return Colors.purple;
    }
  }
}
