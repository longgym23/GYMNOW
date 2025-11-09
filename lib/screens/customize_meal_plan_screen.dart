import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gym_now/models/food_model.dart';
import 'package:gym_now/models/meal_plan_template_model.dart';

class CustomizeMealPlanScreen extends StatefulWidget {
  final MealPlanTemplate template;

  const CustomizeMealPlanScreen({Key? key, required this.template})
    : super(key: key);

  @override
  State<CustomizeMealPlanScreen> createState() =>
      _CustomizeMealPlanScreenState();
}

class _CustomizeMealPlanScreenState extends State<CustomizeMealPlanScreen> {
  // Copy meals để có thể chỉnh sửa
  late List<MealEntry> _customizedMeals;

  @override
  void initState() {
    super.initState();
    // Deep copy meals để có thể chỉnh sửa
    _customizedMeals = widget.template.meals.map((meal) {
      return MealEntry(
        name: meal.name,
        foods: List<String>.from(meal.foods),
        foodNutrition: meal.foodNutrition != null
            ? meal.foodNutrition!
                  .map(
                    (n) => FoodItemNutrition(
                      foodName: n.foodName,
                      unit: n.unit,
                      calories: n.calories,
                      protein: n.protein,
                      carbs: n.carbs,
                      fat: n.fat,
                    ),
                  )
                  .toList()
            : null,
      );
    }).toList();
  }

  Future<FoodItem?> _showFoodSearchDialog() async {
    Stream<QuerySnapshot>? foodsStream;
    String searchQuery = '';
    final TextEditingController searchController = TextEditingController();

    return showDialog<FoodItem>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (foodsStream == null) {
            foodsStream = FirebaseFirestore.instance
                .collection('foods')
                .orderBy('name')
                .limit(50)
                .snapshots();
          }
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: const Color(0xFF1B263B),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.bookmark_add_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Danh sách món ăn',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A3B4F),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Nhập tên món ăn...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.search,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.clear,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                  ),
                                  onPressed: () {
                                    searchController.clear();
                                    setDialogState(() {
                                      searchQuery = '';
                                      foodsStream = FirebaseFirestore.instance
                                          .collection('foods')
                                          .orderBy('name')
                                          .limit(200)
                                          .snapshots();
                                    });
                                  },
                                )
                              : null,
                          filled: false,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            searchQuery = value.toLowerCase();
                            // Lấy tất cả foods và filter ở client-side
                            foodsStream = FirebaseFirestore.instance
                                .collection('foods')
                                .orderBy('name')
                                .limit(200)
                                .snapshots();
                          });
                        },
                      ),
                    ),
                  ),
                  // Food list
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: foodsStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A3B4F),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.restaurant_menu,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Không tìm thấy món ăn',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Helper functions để remove diacritics và match search
                        String removeDiacritics(String str) {
                          const Map<String, String> diacriticsMap = {
                            'à': 'a',
                            'á': 'a',
                            'ạ': 'a',
                            'ả': 'a',
                            'ã': 'a',
                            'â': 'a',
                            'ầ': 'a',
                            'ấ': 'a',
                            'ậ': 'a',
                            'ẩ': 'a',
                            'ẫ': 'a',
                            'ă': 'a',
                            'ằ': 'a',
                            'ắ': 'a',
                            'ặ': 'a',
                            'ẳ': 'a',
                            'ẵ': 'a',
                            'è': 'e',
                            'é': 'e',
                            'ẹ': 'e',
                            'ẻ': 'e',
                            'ẽ': 'e',
                            'ê': 'e',
                            'ề': 'e',
                            'ế': 'e',
                            'ệ': 'e',
                            'ể': 'e',
                            'ễ': 'e',
                            'ì': 'i',
                            'í': 'i',
                            'ị': 'i',
                            'ỉ': 'i',
                            'ĩ': 'i',
                            'ò': 'o',
                            'ó': 'o',
                            'ọ': 'o',
                            'ỏ': 'o',
                            'õ': 'o',
                            'ô': 'o',
                            'ồ': 'o',
                            'ố': 'o',
                            'ộ': 'o',
                            'ổ': 'o',
                            'ỗ': 'o',
                            'ơ': 'o',
                            'ờ': 'o',
                            'ớ': 'o',
                            'ợ': 'o',
                            'ở': 'o',
                            'ỡ': 'o',
                            'ù': 'u',
                            'ú': 'u',
                            'ụ': 'u',
                            'ủ': 'u',
                            'ũ': 'u',
                            'ư': 'u',
                            'ừ': 'u',
                            'ứ': 'u',
                            'ự': 'u',
                            'ử': 'u',
                            'ữ': 'u',
                            'ỳ': 'y',
                            'ý': 'y',
                            'ỵ': 'y',
                            'ỷ': 'y',
                            'ỹ': 'y',
                            'đ': 'd',
                          };

                          String result = str.toLowerCase();
                          diacriticsMap.forEach((vietnamese, english) {
                            result = result.replaceAll(vietnamese, english);
                          });
                          return result;
                        }

                        bool matchesSearch(String foodName, String query) {
                          final normalizedFood = removeDiacritics(foodName);
                          final normalizedQuery = removeDiacritics(query);
                          if (normalizedFood.contains(normalizedQuery)) {
                            return true;
                          }
                          final words = normalizedFood.split(' ');
                          final firstLetters = words
                              .map((w) => w.isNotEmpty ? w[0] : '')
                              .join('');
                          if (firstLetters.contains(normalizedQuery)) {
                            return true;
                          }
                          return false;
                        }

                        final foodDocs = snapshot.data!.docs;
                        final filteredDocs = searchQuery.isNotEmpty
                            ? foodDocs.where((doc) {
                                final food = FoodItem.fromFirestore(doc);
                                return matchesSearch(food.name, searchQuery);
                              }).toList()
                            : foodDocs;

                        if (filteredDocs.isEmpty && searchQuery.isNotEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A3B4F),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.restaurant_menu,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Không tìm thấy món ăn',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            final food = FoodItem.fromFirestore(
                              filteredDocs[index],
                            );
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A3B4F),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => Navigator.pop(context, food),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            gradient: LinearGradient(
                                              colors: [
                                                Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withOpacity(0.3),
                                                Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withOpacity(0.1),
                                              ],
                                            ),
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: _buildFoodImage(
                                              food.name,
                                              60,
                                              60,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                food.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                          .withOpacity(0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .local_fire_department,
                                                          size: 14,
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          '${food.calories.toStringAsFixed(0)} kcal',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '/ ${food.unit}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[400],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: Colors.grey[400],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFoodImage(String foodName, double w, double h) {
    final assetPath = 'assets/images/Anh2/$foodName.jpg';
    return Image.asset(
      assetPath,
      width: w,
      height: h,
      fit: BoxFit.cover,
      errorBuilder: (c, e, s) => Container(
        width: w,
        height: h,
        color: const Color(0xFF2A3B4F),
        child: Icon(Icons.restaurant, size: w * 0.6, color: Colors.white70),
      ),
    );
  }

  void _addFoodToMeal(int mealIndex, FoodItem food) {
    setState(() {
      final meal = _customizedMeals[mealIndex];
      // Tạo meal mới với foods và foodNutrition đã cập nhật
      final newFoods = List<String>.from(meal.foods)..add(food.name);
      final newFoodNutrition = meal.foodNutrition != null
          ? List<FoodItemNutrition>.from(meal.foodNutrition!)
          : <FoodItemNutrition>[];
      newFoodNutrition.add(
        FoodItemNutrition(
          foodName: food.name,
          unit: food.unit,
          calories: food.calories,
          protein: food.protein,
          carbs: food.carbs,
          fat: food.fat,
        ),
      );

      _customizedMeals[mealIndex] = MealEntry(
        name: meal.name,
        foods: newFoods,
        foodNutrition: newFoodNutrition,
      );
    });
  }

  void _removeFoodFromMeal(int mealIndex, int foodIndex) {
    setState(() {
      final meal = _customizedMeals[mealIndex];
      final newFoods = List<String>.from(meal.foods)..removeAt(foodIndex);
      final newFoodNutrition = meal.foodNutrition != null
          ? List<FoodItemNutrition>.from(meal.foodNutrition!)
          : <FoodItemNutrition>[];
      if (foodIndex < newFoodNutrition.length) {
        newFoodNutrition.removeAt(foodIndex);
      }

      _customizedMeals[mealIndex] = MealEntry(
        name: meal.name,
        foods: newFoods,
        foodNutrition: newFoodNutrition.isNotEmpty ? newFoodNutrition : null,
      );
    });
  }

  Widget _buildMealCard(int mealIndex) {
    final meal = _customizedMeals[mealIndex];
    double mealCal = 0;
    if (meal.foodNutrition != null) {
      mealCal = meal.foodNutrition!.fold(0.0, (sum, n) => sum + n.calories);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meal name with total calories and add button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.restaurant,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meal.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            if (mealCal > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.local_fire_department,
                                    size: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${mealCal.toStringAsFixed(0)} calo',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () async {
                      final food = await _showFoodSearchDialog();
                      if (food != null) {
                        _addFoodToMeal(mealIndex, food);
                      }
                    },
                    tooltip: 'Thêm món ăn',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Food items
            if (meal.foodNutrition != null && meal.foodNutrition!.isNotEmpty)
              ...meal.foodNutrition!.asMap().entries.map((entry) {
                final index = entry.key;
                final nutrition = entry.value;
                return _buildFoodItemCard(nutrition, mealIndex, index);
              })
            else if (meal.foods.isNotEmpty)
              ...meal.foods.asMap().entries.map((entry) {
                final index = entry.key;
                final foodName = entry.value;
                return _buildFoodItemChip(foodName, mealIndex, index);
              })
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3B4F).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 32,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chưa có món ăn',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nhấn nút + để thêm món ăn',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodItemCard(
    FoodItemNutrition nutrition,
    int mealIndex,
    int foodIndex,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3B4F),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildFoodImage(nutrition.foodName, 60, 60),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nutrition.foodName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                size: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${nutrition.calories.toStringAsFixed(0)} calo',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${nutrition.unit}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: () => _removeFoodFromMeal(mealIndex, foodIndex),
                  tooltip: 'Xóa món ăn',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoodItemChip(String foodName, int mealIndex, int foodIndex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3B4F),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _buildFoodImage(foodName, 24, 24),
          ),
          const SizedBox(width: 8),
          Text(foodName, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
            onPressed: () => _removeFoodFromMeal(mealIndex, foodIndex),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Xóa món ăn',
          ),
        ],
      ),
    );
  }

  void _saveCustomizedMealPlan() {
    // Return customized meals to parent
    Navigator.pop(context, _customizedMeals);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tùy chỉnh kế hoạch'),
        actions: [
          TextButton(
            onPressed: _saveCustomizedMealPlan,
            child: const Text(
              'Lưu',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info card với gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    const Color(0xFF1B263B),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.restaurant_menu,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Tùy chỉnh thực đơn',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Thêm hoặc xóa món ăn trong các bữa ăn. Nhấn nút + để thêm món ăn mới.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Meal cards
            ..._customizedMeals.asMap().entries.map((entry) {
              return _buildMealCard(entry.key);
            }),
          ],
        ),
      ),
    );
  }
}
