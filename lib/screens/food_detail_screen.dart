import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gym_now/models/food_model.dart';

class FoodDetailScreen extends StatelessWidget {
  final FoodItem food;

  const FoodDetailScreen({Key? key, required this.food}) : super(key: key);

  List<PieChartSectionData> _buildRingSections(ThemeData theme) {
    // Tính tổng bao gồm cả chất xơ nếu có
    final gramsTotal = (food.protein + food.carbs + food.fat + food.fiber)
        .clamp(0.0001, double.infinity);
    final p = food.protein / gramsTotal * 100;
    final c = food.carbs / gramsTotal * 100;
    final f = food.fat / gramsTotal * 100;
    final fiber = food.fiber / gramsTotal * 100;

    final sections = <PieChartSectionData>[
      PieChartSectionData(value: c, color: Colors.blueAccent, title: ''),
      PieChartSectionData(value: f, color: Colors.amber, title: ''),
      PieChartSectionData(value: p, color: Colors.deepPurple, title: ''),
    ];

    // Thêm chất xơ vào biểu đồ nếu có
    if (food.fiber > 0) {
      sections.add(
        PieChartSectionData(value: fiber, color: Colors.green, title: ''),
      );
    }

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image Section với gradient overlay
            Stack(
              children: [
                Hero(
                  tag: 'food_image_${food.id}',
                  child: _buildFoodHeaderImage(food),
                ),
                // Gradient overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF0D1B2A).withOpacity(0.8),
                          const Color(0xFF0D1B2A),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Food Name và Calories per serving trong cùng một row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          food.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${food.calories.toStringAsFixed(0)} kcal',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    food.unit,
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),

                  const SizedBox(height: 16),

                  // Nutrition Overview Card - Biểu đồ và thông tin dinh dưỡng cùng nhau
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B263B),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Donut Chart - thu nhỏ hơn
                        Container(
                          height: 150,
                          width: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.15),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  sections: _buildRingSections(theme),
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 38,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    food.calories.toStringAsFixed(0),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Text(
                                    'Calo',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Macro Stats - thu nhỏ và có khoảng cách rõ ràng
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _MacroStat(
                                color: Colors.deepPurple,
                                percent: _percent(food.protein, food),
                                gramsText:
                                    '${food.protein.toStringAsFixed(1)} g',
                                label: 'CHẤT ĐẠM',
                                icon: Icons.bolt,
                              ),
                              const SizedBox(height: 6),
                              _MacroStat(
                                color: Colors.blueAccent,
                                percent: _percent(food.carbs, food),
                                gramsText: '${food.carbs.toStringAsFixed(1)} g',
                                label: 'ĐƯỜNG BỘT',
                                icon: Icons.grain,
                              ),
                              const SizedBox(height: 6),
                              _MacroStat(
                                color: Colors.amber,
                                percent: _percent(food.fat, food),
                                gramsText: '${food.fat.toStringAsFixed(1)} g',
                                label: 'CHẤT BÉO',
                                icon: Icons.oil_barrel,
                              ),
                              if (food.fiber > 0) ...[
                                const SizedBox(height: 6),
                                _MacroStat(
                                  color: Colors.green,
                                  percent: _percent(food.fiber, food),
                                  gramsText:
                                      '${food.fiber.toStringAsFixed(1)} g',
                                  label: 'CHẤT XƠ',
                                  icon: Icons.eco,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Description Section
                  if (food.description.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B263B),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.info_outline,
                                  color: Colors.blueAccent,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Mô tả',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            food.description,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: Colors.white70,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  if (food.description.isNotEmpty) const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _percent(double value, FoodItem item) {
    // Tính phần trăm dựa trên tổng bao gồm cả chất xơ
    final total = (item.protein + item.carbs + item.fat + item.fiber).clamp(
      0.0001,
      double.infinity,
    );
    return (value / total * 100);
  }
}

Widget _buildFoodHeaderImage(FoodItem food) {
  final src = food.imageUrl;
  if (src.isNotEmpty && src.startsWith('http')) {
    return Image.network(
      src,
      height: 220,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (c, e, s) => _buildPlaceholderImage(),
    );
  }
  final assetPath = src.isNotEmpty && src.startsWith('asset:')
      ? src.replaceFirst('asset:', '')
      : 'assets/images/Anh/${food.name}.jpg';
  return Image.asset(
    assetPath,
    height: 220,
    width: double.infinity,
    fit: BoxFit.cover,
    errorBuilder: (c, e, s) => _buildPlaceholderImage(),
  );
}

Widget _buildPlaceholderImage() {
  return Container(
    height: 220,
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFF1B263B), const Color(0xFF0D1B2A)],
      ),
    ),
    child: const Center(
      child: Icon(Icons.restaurant, size: 48, color: Colors.white30),
    ),
  );
}

class _MacroStat extends StatelessWidget {
  final Color color;
  final double percent; // 0..100
  final String gramsText;
  final String label;
  final IconData icon;

  const _MacroStat({
    Key? key,
    required this.color,
    required this.percent,
    required this.gramsText,
    required this.label,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  gramsText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${percent.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
