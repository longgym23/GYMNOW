import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gym_now/models/food_model.dart';

class FoodDetailScreen extends StatelessWidget {
  final FoodItem food;

  const FoodDetailScreen({Key? key, required this.food}) : super(key: key);

  List<PieChartSectionData> _buildRingSections(ThemeData theme) {
    final gramsTotal = (food.protein + food.carbs + food.fat).clamp(
      0.0001,
      double.infinity,
    );
    final p = food.protein / gramsTotal * 100;
    final c = food.carbs / gramsTotal * 100;
    final f = food.fat / gramsTotal * 100;
    return [
      PieChartSectionData(value: c, color: Colors.blueAccent, title: ''),
      PieChartSectionData(value: f, color: Colors.amber, title: ''),
      PieChartSectionData(value: p, color: Colors.deepPurple, title: ''),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(food.name)),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildFoodHeaderImage(food),
            ),
            const SizedBox(height: 12),
            // Center(
            //   child: Text(
            //     food.name,
            //     style: const TextStyle(
            //       fontSize: 28,
            //       fontWeight: FontWeight.w700,
            //     ),
            //     textAlign: TextAlign.center,
            //   ),
            // ),
            const SizedBox(height: 12),
            // Vòng tròn kcal + 3 thẻ macro như hình 2
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Donut kcal
                SizedBox(
                  height: 140,
                  width: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: _buildRingSections(theme),
                          sectionsSpace: 2,
                          centerSpaceRadius: 46,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            food.calories.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text('Cal'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Macro cards
                Expanded(
                  child: Column(
                    children: [
                      _MacroStat(
                        color: Colors.deepPurple,
                        percent: _percent(food.protein, food),
                        gramsText: '${food.protein.toStringAsFixed(1)} g',
                        label: 'CHẤT ĐẠM',
                        icon: Icons.bolt,
                      ),
                      const SizedBox(height: 12),
                      _MacroStat(
                        color: Colors.blueAccent,
                        percent: _percent(food.carbs, food),
                        gramsText: '${food.carbs.toStringAsFixed(1)} g',
                        label: 'ĐƯỜNG BỘT',
                        icon: Icons.grain,
                      ),
                      const SizedBox(height: 12),
                      _MacroStat(
                        color: Colors.amber,
                        percent: _percent(food.fat, food),
                        gramsText: '${food.fat.toStringAsFixed(1)} g',
                        label: 'CHẤT BÉO',
                        icon: Icons.oil_barrel,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '${food.calories.toStringAsFixed(0)} kcal / ${food.unit}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _percent(double value, FoodItem item) {
    final total = (item.protein + item.carbs + item.fat).clamp(
      0.0001,
      double.infinity,
    );
    return (value / total * 100);
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({Key? key, required this.color, required this.label})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

Widget _buildFoodHeaderImage(FoodItem food) {
  final src = food.imageUrl;
  if (src.isNotEmpty && src.startsWith('http')) {
    return Image.network(
      src,
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }
  final assetPath = src.isNotEmpty && src.startsWith('asset:')
      ? src.replaceFirst('asset:', '')
      : 'assets/images/Anh/${food.name}.jpg';
  return Image.asset(
    assetPath,
    height: 180,
    width: double.infinity,
    fit: BoxFit.cover,
    errorBuilder: (c, e, s) => Container(
      height: 180,
      color: const Color(0xFF1B263B),
      alignment: Alignment.center,
      child: const Icon(Icons.restaurant, size: 32),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${percent.toStringAsFixed(0)} %',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            gramsText,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
