import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gym_now/models/meal_plan_template_model.dart';

class MealPlanImportScreen extends StatefulWidget {
  const MealPlanImportScreen({Key? key}) : super(key: key);

  @override
  State<MealPlanImportScreen> createState() => _MealPlanImportScreenState();
}

class _MealPlanImportScreenState extends State<MealPlanImportScreen> {
  bool _importing = false;
  String _status = '';
  int _imported = 0;
  int _importedLoseWeight = 0;
  int _importedMaintainWeight = 0;
  int _importedGainMuscle = 0;

  // Cache for macro nutrition data - separate cache for each category
  Map<MealPlanCategory, Map<String, FoodItemNutrition>> _macroCacheByCategory =
      {};

  List<String> _parseFoodItems(String mealText) {
    // Parse "Bánh mì đen + trứng ốp la + sữa tách béo" into ["Bánh mì đen", "trứng ốp la", "sữa tách béo"]
    // Simple split by "+"
    return mealText
        .split('+')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toList();
  }

  // Get CSV file path for nutrition data based on category
  String _getNutritionCsvPath(MealPlanCategory category) {
    switch (category) {
      case MealPlanCategory.loseWeight:
        return 'csv_importer/Giảm Cân.csv';
      case MealPlanCategory.maintainWeight:
        return 'csv_importer/Giữ Dáng.csv';
      case MealPlanCategory.gainMuscle:
        return 'csv_importer/Tăng Cơ.csv';
      default:
        return 'csv_importer/Giữ Dáng.csv'; // Default fallback
    }
  }

  // Load macro nutrition data from CSV for specific category
  Future<void> _loadMacroNutritionForCategory(MealPlanCategory category) async {
    // Check if already loaded for this category
    if (_macroCacheByCategory.containsKey(category)) return;

    final cache = <String, FoodItemNutrition>{};
    try {
      final csvPath = _getNutritionCsvPath(category);
      final data = await rootBundle.loadString(csvPath);
      final lines = data.split('\n').where((l) => l.trim().isNotEmpty).toList();

      // Skip header
      for (final line in lines.skip(1)) {
        final parts = _parseCsvRow(line);
        if (parts.length < 5) continue;

        final monAn = parts[0].trim();
        final calories = double.tryParse(parts[1].trim()) ?? 0;
        final protein = double.tryParse(parts[2].trim()) ?? 0;
        final carbs = double.tryParse(parts[3].trim()) ?? 0;
        final fat = double.tryParse(parts[4].trim()) ?? 0;

        // Extract unit from name (e.g., "Yến mạch (40g)" -> unit: "40g")
        String unit = '';
        String foodName = monAn;
        final unitMatch = RegExp(r'\(([^)]+)\)').firstMatch(monAn);
        if (unitMatch != null) {
          unit = unitMatch.group(1) ?? '';
          foodName = monAn.replaceAll(RegExp(r'\s*\([^)]+\)'), '').trim();
        }

        // Normalize food name for matching
        final normalizedName = _normalizeFoodName(foodName);

        cache[normalizedName] = FoodItemNutrition(
          foodName: foodName,
          unit: unit.isNotEmpty ? unit : '100g',
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
        );
      }

      _macroCacheByCategory[category] = cache;
      print(
        '✅ Loaded ${cache.length} food items from $csvPath for ${_getCategoryName(category)}',
      );
      // Debug: Print first few cache keys
      if (cache.isNotEmpty) {
        print('   Sample cache keys (first 5): ${cache.keys.take(5).toList()}');
      }
    } catch (e, stackTrace) {
      print(
        '❌ ERROR loading nutrition CSV for ${_getCategoryName(category)}: $e',
      );
      print('Stack trace: $stackTrace');
      print('CSV path attempted: ${_getNutritionCsvPath(category)}');
      _macroCacheByCategory[category] = {};
      rethrow; // Re-throw để caller biết có lỗi
    }
  }

  // Normalize food name for matching
  String _normalizeFoodName(String name) {
    return name.toLowerCase().trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    ); // Normalize spaces
  }

  // Find nutrition data by food name for specific category
  FoodItemNutrition? _findMacroByName(
    String foodName,
    MealPlanCategory category,
  ) {
    final cache = _macroCacheByCategory[category];
    if (cache == null || cache.isEmpty) {
      print('⚠️ Cache trống cho category: ${_getCategoryName(category)}');
      return null;
    }

    final normalized = _normalizeFoodName(foodName);
    print(
      '🔍 Tìm kiếm: "$foodName" (normalized: "$normalized") trong ${cache.length} items',
    );

    // Try exact match first
    if (cache.containsKey(normalized)) {
      final nutrition = cache[normalized]!;
      print('✅ Exact match: "$foodName" -> ${nutrition.calories} cal');
      return FoodItemNutrition(
        foodName: foodName, // Use original name from meal plan
        unit: nutrition.unit,
        calories: nutrition.calories,
        protein: nutrition.protein,
        carbs: nutrition.carbs,
        fat: nutrition.fat,
      );
    }

    // Try partial match with better logic
    // Remove common prefixes/suffixes and try matching
    String cleanName = normalized;
    // Remove common prefixes like "1 quả", "1 lát", etc.
    cleanName = cleanName.replaceAll(
      RegExp(r'^\d+\s*(quả|lát|cái|g|ml|kg|gram|gam)\s*'),
      '',
    );
    cleanName = cleanName.trim();

    // Try matching with cleaned name
    // Cache key đã là normalized name (không có unit), nên chỉ cần so sánh trực tiếp
    for (final entry in cache.entries) {
      final cacheName = entry.key; // Đã là normalized name từ khi load CSV
      // Cache name đã được normalize và không có unit trong ngoặc
      // Vì khi load CSV, chúng ta đã extract unit và normalize tên

      // Check multiple matching strategies
      bool matches = false;

      // Strategy 1: Exact match (cả hai đã được normalize)
      if (cleanName == cacheName || normalized == cacheName) {
        matches = true;
      }
      // Strategy 2: One contains the other
      else if (cleanName.contains(cacheName) || cacheName.contains(cleanName)) {
        matches = true;
      }
      // Strategy 3: Word-by-word matching (e.g., "trứng ốp la" matches "trứng ốp la")
      else {
        final foodWords = cleanName.split(RegExp(r'\s+'));
        final cacheWords = cacheName.split(RegExp(r'\s+'));
        if (foodWords.length == cacheWords.length) {
          bool allWordsMatch = true;
          for (int i = 0; i < foodWords.length; i++) {
            if (foodWords[i] != cacheWords[i]) {
              allWordsMatch = false;
              break;
            }
          }
          matches = allWordsMatch;
        }
      }

      if (matches) {
        final nutrition = entry.value;
        print(
          '✅ Partial match: "$foodName" -> "${nutrition.foodName}" (${nutrition.calories} cal)',
        );
        return FoodItemNutrition(
          foodName: foodName, // Use original name from meal plan
          unit: nutrition.unit,
          calories: nutrition.calories,
          protein: nutrition.protein,
          carbs: nutrition.carbs,
          fat: nutrition.fat,
        );
      }
    }

    print('❌ Không tìm thấy match cho: "$foodName"');
    // Debug: Print first few cache keys
    if (cache.isNotEmpty) {
      print('   Cache keys (first 5): ${cache.keys.take(5).toList()}');
    }
    return null;
  }

  Future<void> _importCsvFile(
    String assetPath,
    MealPlanCategory category,
  ) async {
    try {
      // Đảm bảo nutrition cache đã được load trước khi import
      print(
        '🔄 Đảm bảo cache đã load cho category: ${_getCategoryName(category)}',
      );
      await _loadMacroNutritionForCategory(category);

      // Kiểm tra cache sau khi load
      final cache = _macroCacheByCategory[category];
      if (cache == null || cache.isEmpty) {
        print(
          '❌ ERROR: Cache vẫn trống sau khi load cho ${_getCategoryName(category)}!',
        );
        _status =
            'Lỗi: Không thể load dữ liệu dinh dưỡng cho ${_getCategoryName(category)}';
        setState(() {});
        return;
      }
      print(
        '✅ Cache đã sẵn sàng: ${cache.length} items cho ${_getCategoryName(category)}',
      );

      _status = 'Đang đọc file: $assetPath...';
      setState(() {});

      final data = await rootBundle.loadString(assetPath);
      final lines = data.split('\n').where((l) => l.trim().isNotEmpty).toList();

      if (lines.isEmpty) {
        _status = 'File CSV trống: $assetPath';
        setState(() {});
        return;
      }

      // Skip header
      final rows = lines.skip(1).toList();
      int imported = 0;

      _status =
          'Đang import ${_getCategoryName(category)}... (${rows.length} thực đơn)';
      setState(() {});

      for (final row in rows) {
        if (row.trim().isEmpty) continue;

        final parts = _parseCsvRow(row);
        if (parts.length < 10)
          continue; // MenuID,BuaSang,BuaTrua,BuaPhu1,BuaToi,BuaPhu2,Calories,Protein(g),Carbs(g),Fat(g)

        final menuId = parts[0];
        final buaSang = parts[1];
        final buaTrua = parts[2];
        final buaPhu1 = parts[3];
        final buaToi = parts[4];
        final buaPhu2 = parts.length > 5 ? parts[5] : '';
        // New format has nutrition values in CSV
        // Ensure we have enough parts and parse correctly
        if (parts.length < 10) {
          _status = 'Lỗi: Dòng $menuId không đủ cột (${parts.length}/10)';
          setState(() {});
          continue;
        }

        final totalCalories = double.tryParse(parts[6].trim()) ?? 0;
        final totalProtein = double.tryParse(parts[7].trim()) ?? 0;
        final totalCarbs = double.tryParse(parts[8].trim()) ?? 0;
        final totalFat = double.tryParse(parts[9].trim()) ?? 0;

        // Debug: Log first menu to verify
        if (imported == 0 && menuId == '1') {
          print(
            'Menu 1 - Calories: $totalCalories, Protein: $totalProtein, Carbs: $totalCarbs, Fat: $totalFat',
          );
          print(
            'Parts[6]: "${parts[6]}", Parts[7]: "${parts[7]}", Parts[8]: "${parts[8]}", Parts[9]: "${parts[9]}"',
          );
        }

        // Create meal entries with nutrition details
        final meals = <MealEntry>[];

        // Helper to create meal entry with nutrition
        MealEntry createMealEntry(String mealName, String mealText) {
          final foods = _parseFoodItems(mealText);
          final foodNutrition = <FoodItemNutrition>[];

          print(
            '🔍 Creating meal entry: "$mealName" with ${foods.length} foods',
          );

          for (final food in foods) {
            final nutrition = _findMacroByName(food, category);
            if (nutrition != null && nutrition.calories > 0) {
              foodNutrition.add(nutrition);
              print(
                '✅ Found nutrition for "$food": ${nutrition.calories} cal, ${nutrition.protein}g protein, ${nutrition.carbs}g carbs, ${nutrition.fat}g fat',
              );
            } else {
              print(
                '❌ Không tìm thấy nutrition cho "$food" trong ${_getCategoryName(category)}',
              );
              // KHÔNG thêm với giá trị 0 - chỉ thêm nếu tìm thấy
              // Điều này giúp debug dễ hơn
            }
          }

          print(
            '📊 Meal "$mealName": ${foods.length} foods parsed, ${foodNutrition.length} nutrition items found',
          );

          if (foodNutrition.isEmpty) {
            print(
              '⚠️ WARNING: Meal "$mealName" không có nutrition data! Tất cả món ăn đều không match được.',
            );
            // Vẫn trả về MealEntry nhưng với foodNutrition = null để fallback hiển thị
            return MealEntry(name: mealName, foods: foods, foodNutrition: null);
          }

          return MealEntry(
            name: mealName,
            foods: foods,
            foodNutrition: foodNutrition,
          );
        }

        if (buaSang.isNotEmpty) {
          meals.add(createMealEntry('Buổi sáng', buaSang));
        }
        if (buaTrua.isNotEmpty) {
          meals.add(createMealEntry('Buổi trưa', buaTrua));
        }
        if (buaPhu1.isNotEmpty) {
          meals.add(createMealEntry('Bữa phụ 1', buaPhu1));
        }
        if (buaToi.isNotEmpty) {
          meals.add(createMealEntry('Buổi tối', buaToi));
        }
        if (buaPhu2.isNotEmpty) {
          meals.add(createMealEntry('Bữa phụ 2', buaPhu2));
        }

        // Use nutrition values directly from CSV (total values for entire meal plan)

        // Validate nutrition values
        if (totalCalories == 0) {
          _status = 'Cảnh báo: Menu $menuId có Calories = 0. Kiểm tra lại CSV.';
          setState(() {});
        }

        // Create template - use values directly from CSV
        final template = MealPlanTemplate(
          id: '',
          name: _getCategoryName(category) + ' - Menu $menuId',
          description:
              'Thực đơn ${_getCategoryName(category).toLowerCase()} số $menuId',
          category: category,
          targetCalories:
              totalCalories, // Directly from CSV column 7 (parts[6])
          targetProtein: totalProtein, // Directly from CSV column 8 (parts[7])
          targetCarbs: totalCarbs, // Directly from CSV column 9 (parts[8])
          targetFat: totalFat, // Directly from CSV column 10 (parts[9])
          meals: meals,
          imageUrl: '', // Empty image URL for now
          createdAt: Timestamp.now(),
        );

        // Debug: Print template data before saving
        if (imported == 0 && menuId == '1') {
          print('Template data for Menu 1:');
          print('  Name: ${template.name}');
          print('  Category: ${template.category}');
          print('  Calories: ${template.targetCalories}');
          print('  Meals count: ${template.meals.length}');
          print('  ToMap: ${template.toMap()}');
        }

        // Save to Firestore
        try {
          final docRef = await FirebaseFirestore.instance
              .collection('mealPlanTemplates')
              .add(template.toMap());

          imported++;
          print('✅ Saved Menu $menuId with ID: ${docRef.id}');

          if (imported % 10 == 0 || imported == rows.length) {
            _status =
                'Đang import ${_getCategoryName(category)}: $imported/${rows.length} thực đơn...';
            setState(() {});
          }
        } catch (e, stackTrace) {
          _status = 'Lỗi khi lưu Menu $menuId: $e';
          setState(() {});
          print('❌ Error saving menu $menuId: $e');
          print('Stack trace: $stackTrace');
          continue;
        }
      }

      _imported += imported;

      // Track imported count by category
      switch (category) {
        case MealPlanCategory.loseWeight:
          _importedLoseWeight = imported;
          break;
        case MealPlanCategory.maintainWeight:
          _importedMaintainWeight = imported;
          break;
        case MealPlanCategory.gainMuscle:
          _importedGainMuscle = imported;
          break;
        default:
          break;
      }

      _status =
          'Hoàn thành! Đã import $imported thực đơn từ ${_getCategoryName(category)}.';
      setState(() {});
      print(
        'Successfully imported $imported meal plans from ${_getCategoryName(category)}',
      );
    } catch (e, stackTrace) {
      _status = 'Lỗi khi import $assetPath: $e\n\nStack trace: $stackTrace';
      setState(() {});
      print('Error importing $assetPath: $e');
      print('Stack trace: $stackTrace');
    }
  }

  String _getCategoryName(MealPlanCategory category) {
    switch (category) {
      case MealPlanCategory.loseWeight:
        return 'Giảm cân';
      case MealPlanCategory.maintainWeight:
        return 'Giữ dáng';
      case MealPlanCategory.gainWeight:
        return 'Tăng cân';
      case MealPlanCategory.gainMuscle:
        return 'Tăng cơ';
    }
  }

  List<String> _parseCsvRow(String row) {
    final result = <String>[];
    bool inQuotes = false;
    String current = '';

    for (int i = 0; i < row.length; i++) {
      final char = row[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.trim());
        current = '';
      } else {
        current += char;
      }
    }
    result.add(current.trim()); // Add last field

    return result;
  }

  Future<void> _importAll() async {
    setState(() {
      _importing = true;
      _status = 'Bắt đầu import...';
      _imported = 0;
      _importedLoseWeight = 0;
      _importedMaintainWeight = 0;
      _importedGainMuscle = 0;
    });

    try {
      print('=== Starting import process ===');

      // Load macro nutrition data for each category
      _status = 'Đang tải dữ liệu dinh dưỡng từ các file CSV...';
      setState(() {});
      await _loadMacroNutritionForCategory(MealPlanCategory.loseWeight);
      await _loadMacroNutritionForCategory(MealPlanCategory.maintainWeight);
      await _loadMacroNutritionForCategory(MealPlanCategory.gainMuscle);
      _status = 'Đã tải xong dữ liệu dinh dưỡng. Bắt đầu import...';
      setState(() {});

      // Test Firestore connection first
      try {
        _status = 'Đang kiểm tra kết nối Firestore...';
        setState(() {});
        final testRef = FirebaseFirestore.instance
            .collection('mealPlanTemplates')
            .doc('test');
        await testRef.set({'test': true});
        await testRef.delete();
        print('✅ Firestore connection OK');
        _status = 'Kết nối Firestore thành công. Bắt đầu import...';
        setState(() {});
      } catch (e) {
        _status =
            '❌ Lỗi kết nối Firestore: $e\n\nVui lòng kiểm tra:\n'
            '1. Firestore rules cho phép write\n'
            '2. Firebase đã được cấu hình đúng\n'
            '3. Internet connection';
        setState(() {});
        print('❌ Firestore connection failed: $e');
        return;
      }

      // Import each CSV file directly - no need for macro_tung_mon.csv
      await _importCsvFile(
        'csv_importer/Giamcan.csv',
        MealPlanCategory.loseWeight, // Giảm cân
      );

      await _importCsvFile(
        'csv_importer/Giudang.csv',
        MealPlanCategory.maintainWeight, // Giữ dáng
      );

      await _importCsvFile(
        'csv_importer/Tangco.csv',
        MealPlanCategory.gainMuscle, // Tăng cơ
      );

      _status =
          '✅ Hoàn thành! Tổng cộng đã import $_imported thực đơn.\n\n'
          '- Giảm cân: $_importedLoseWeight thực đơn\n'
          '- Giữ dáng: $_importedMaintainWeight thực đơn\n'
          '- Tăng cơ: $_importedGainMuscle thực đơn\n\n'
          'Vui lòng kiểm tra Firestore collection "mealPlanTemplates" để xác nhận.';
      print('=== Import completed ===');
      print('Total: $_imported');
      print('  - Lose Weight: $_importedLoseWeight');
      print('  - Maintain Weight: $_importedMaintainWeight');
      print('  - Gain Muscle: $_importedGainMuscle');
    } catch (e, stackTrace) {
      _status = '❌ Lỗi import: $e\n\nStack trace:\n$stackTrace';
      print('❌ Import error: $e');
      print('Stack trace: $stackTrace');
    } finally {
      setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Meal Plan Templates')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Import Meal Plan Templates',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Script này sẽ import các file CSV meal plan vào Firestore collection "mealPlanTemplates".\n'
                      'Các file CSV sẽ được đọc từ assets:\n'
                      '- Giamcan.csv → Giảm cân (loseWeight)\n'
                      '- Giudang.csv → Giữ dáng (maintainWeight)\n'
                      '- Tangco.csv → Tăng cơ (gainMuscle)\n'
                      'Mỗi menu trong CSV đã có sẵn tổng calories, protein, carbs, fat.',
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _importing ? null : _importAll,
                      icon: _importing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload),
                      label: const Text('Import Tất Cả'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_status.isNotEmpty)
              Card(
                color: const Color(0xFF1B263B),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _status,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            if (_imported > 0)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Đã import: $_imported thực đơn',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
