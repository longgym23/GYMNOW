import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gym_now/models/food_model.dart';
import 'package:gym_now/screens/food_detail_screen.dart';
import 'package:gym_now/screens/food_analyzer_screen.dart';
import 'package:gym_now/screens/meal_plan_templates_screen.dart';
import 'package:gym_now/screens/my_meal_plan_screen.dart';
import 'package:gym_now/screens/nutrition_goal_setup_screen.dart';
import 'package:gym_now/screens/schedule_food_log_screen.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({Key? key}) : super(key: key);

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Stream<QuerySnapshot>? _foodsStream; // Stream để tải dữ liệu

  @override
  void initState() {
    super.initState();
    _buildFirestoreQuery(); // Khởi tạo stream ban đầu
  }

  /// Xây dựng/Cập nhật truy vấn Firestore
  void _buildFirestoreQuery() {
    Query query = FirebaseFirestore.instance.collection('foods');

    if (_searchQuery.isNotEmpty) {
      // Dùng orderBy trên cùng trường với range để tránh lỗi index
      final key = _searchQuery.toLowerCase();
      query = query.orderBy('searchName').startAt([key]).endAt([
        '${key}\uf8ff',
      ]);
    } else {
      query = query.orderBy('name');
    }

    setState(() {
      _foodsStream = query.limit(50).snapshots(); // Giới hạn 50 kết quả
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dinh dưỡng'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Món ăn'),
              Tab(text: 'Thực đơn của bạn'),
              Tab(text: 'Thực đơn tự tạo'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.flag),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NutritionGoalSetupScreen(),
                  ),
                );
              },
              tooltip: 'Thiết lập mục tiêu',
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // TAB 1: Món ăn
            Column(
              children: [
                // Header với gradient
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        Theme.of(context).scaffoldBackgroundColor,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // Thanh Tìm kiếm hiện đại
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A3B4F),
                            borderRadius: BorderRadius.circular(30.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Tìm kiếm món ăn...',
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
                              suffixIcon: _searchQuery.isNotEmpty
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
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                        _buildFirestoreQuery();
                                      },
                                    )
                                  : null,
                              filled: false,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                                _buildFirestoreQuery();
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Tiêu đề với icon
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                              "Danh sách món ăn",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // Danh sách kết quả
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _foodsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Lỗi tải dữ liệu.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
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
                                  color: const Color(0xFF1B263B),
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
                                'Không tìm thấy món ăn nào.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final foodDocs = snapshot.data!.docs;

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: foodDocs.length,
                        itemBuilder: (context, index) {
                          final food = FoodItem.fromFirestore(foodDocs[index]);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
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
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          FoodDetailScreen(food: food),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      // Ảnh món ăn với border gradient
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            16,
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
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: _buildFoodImage(food, 70, 70),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Thông tin món ăn
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              food.name,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.3,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
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
                                                        size: 16,
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${food.calories.toStringAsFixed(0)} kcal',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '/ ${food.unit}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[400],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Nút thêm và mũi tên
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withOpacity(0.7),
                                                ],
                                              ),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withOpacity(0.4),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.add,
                                                color: Colors.white,
                                              ),
                                              onPressed: () async {
                                                final ok =
                                                    await Navigator.of(
                                                      context,
                                                    ).push<bool>(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            ScheduleFoodLogScreen(
                                                              food: food,
                                                            ),
                                                      ),
                                                    );
                                                if (ok == true && mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: const Text(
                                                        'Đã thêm vào Nhật ký.',
                                                      ),
                                                      backgroundColor: Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                      behavior: SnackBarBehavior
                                                          .floating,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                              tooltip: 'Thêm vào Nhật ký',
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 14,
                                            color: Colors.grey[400],
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
                      );
                    },
                  ),
                ),
                // FloatingActionButton phân tích ảnh
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FoodAnalyzerScreen(),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Phân tích từ ảnh',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // TAB 2: Thực đơn của bạn
            const MyMealPlanScreen(),
            // TAB 3: Thực đơn tự tạo
            const MealPlanTemplatesScreen(),
          ],
        ),
      ),
    );
  }
}

Widget _buildFoodImage(FoodItem food, double w, double h) {
  final src = food.imageUrl;
  if (src.isNotEmpty && src.startsWith('http')) {
    return Image.network(src, width: w, height: h, fit: BoxFit.cover);
  }
  // Mặc định dùng ảnh trong assets/images/Anh/{Tên món}.jpg
  final assetPath = src.isNotEmpty && src.startsWith('asset:')
      ? src.replaceFirst('asset:', '')
      : 'assets/images/Anh/${food.name}.jpg';
  return Image.asset(
    assetPath,
    width: w,
    height: h,
    fit: BoxFit.cover,
    errorBuilder: (c, e, s) => const Icon(Icons.restaurant),
  );
}
