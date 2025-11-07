import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

class FoodAnalyzerScreen extends StatefulWidget {
  const FoodAnalyzerScreen({Key? key}) : super(key: key);

  @override
  State<FoodAnalyzerScreen> createState() => _FoodAnalyzerScreenState();
}

class _FoodAnalyzerScreenState extends State<FoodAnalyzerScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  bool _loading = false;
  Map<String, dynamic>? _result; // JSON trả về từ server

  Future<void> _pick(ImageSource source) async {
    final img = await _picker.pickImage(
      source: source,
      maxWidth: 1000,
      imageQuality: 80,
    );
    if (img != null) {
      setState(() {
        _image = img;
        _result = null;
      });
    }
  }

  Future<void> _analyze() async {
    if (_image == null) return;
    setState(() => _loading = true);
    try {
      final bytes = await _image!.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mime = lookupMimeType(_image!.path) ?? 'image/jpeg';

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bạn cần đăng nhập.')));
        return;
      }
      final idToken = await user.getIdToken();

      // Dùng endpoint đã có sẵn trên backend: /askPTAI (hỗ trợ ảnh)
      const url = 'https://gymnow-pt-ai.onrender.com/askPTAI';
      const prompt =
          'Hãy phân tích chi tiết món ăn/đồ uống trong ảnh và trả về CHỈ MỘT JSON hợp lệ. '
          'Bao gồm tất cả thông tin dinh dưỡng có thể: '
          '{"dishName": string, "brand": string (nếu có), "ingredients": string[], "servingUnit": string, '
          '"calories": number, "protein": number, "carbs": number, "fat": number, "fiber": number, '
          '"sugar": number (nếu có), "sodium": number (nếu có), "cholesterol": number (nếu có), '
          '"vitamins": object (nếu có), "minerals": object (nếu có), "description": string (mô tả ngắn) }. '
          'Ước tính dựa trên khẩu phần nhìn thấy trong ảnh.';

      final resp = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'message': prompt,
              'imageBase64': base64Image,
              'mimeType': mime,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final reply = (data['reply'] ?? '').toString();
        final match = RegExp(r'\{[\s\S]*\}').firstMatch(reply);
        if (match != null) {
          final jsonStr = match.group(0)!;
          final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

          // Chuẩn hóa tất cả các trường số một cách linh hoạt
          double _toD(v) =>
              (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0;

          // Chuẩn hóa các trường số chính (nếu có)
          final numFields = [
            'calories',
            'protein',
            'carbs',
            'fat',
            'fiber',
            'sugar',
            'sodium',
            'cholesterol',
          ];
          for (final key in numFields) {
            if (parsed.containsKey(key)) {
              parsed[key] = _toD(parsed[key]);
            }
          }

          // Giữ nguyên tất cả các trường khác từ AI
          setState(() => _result = parsed);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI không trả về JSON hợp lệ.')),
          );
        }
      } else {
        final err = utf8.decode(resp.bodyBytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${resp.statusCode} - $err')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi phân tích: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PieChartSectionData> _sections() {
    if (_result == null) return [];
    final protein = (_result!.containsKey('protein') ? _result!['protein'] : 0)
        .toDouble();
    final carbs = (_result!.containsKey('carbs') ? _result!['carbs'] : 0)
        .toDouble();
    final fat = (_result!.containsKey('fat') ? _result!['fat'] : 0).toDouble();
    final total = (protein + carbs + fat).clamp(0.0001, double.infinity);
    if (total == 0) return [];
    return [
      if (protein > 0)
        PieChartSectionData(
          value: protein / total * 100,
          color: Colors.purple,
          title: 'P',
        ),
      if (carbs > 0)
        PieChartSectionData(
          value: carbs / total * 100,
          color: Colors.blue,
          title: 'C',
        ),
      if (fat > 0)
        PieChartSectionData(
          value: fat / total * 100,
          color: Colors.amber,
          title: 'F',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phân tích món ăn từ ảnh')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Chụp ảnh'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Thư viện'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(_image!.path), fit: BoxFit.cover),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _analyze,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.analytics),
              label: const Text('Phân tích ảnh'),
            ),
            const SizedBox(height: 16),
            if (_result != null) ...[
              Center(
                child: SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: _sections(),
                      centerSpaceRadius: 42,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Thông tin cơ bản
              _infoRow('Món ăn', (_result!['dishName'] ?? '').toString()),
              if ((_result!['brand'] ?? '').toString().isNotEmpty)
                _infoRow('Thương hiệu', _result!['brand'].toString()),
              if ((_result!['description'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B263B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _result!['description'].toString(),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              _infoRow('Khẩu phần', (_result!['servingUnit'] ?? '').toString()),
              const Divider(height: 24),
              // Dinh dưỡng chính
              const Text(
                'Dinh dưỡng chính',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_result!.containsKey('calories'))
                _infoRow('Calo', '${_result!['calories']} kcal'),
              if (_result!.containsKey('protein'))
                _infoRow('Protein', '${_result!['protein']} g'),
              if (_result!.containsKey('carbs'))
                _infoRow('Carb', '${_result!['carbs']} g'),
              if (_result!.containsKey('fat'))
                _infoRow('Fat', '${_result!['fat']} g'),
              if (_result!.containsKey('fiber'))
                _infoRow('Chất xơ', '${_result!['fiber']} g'),
              // Dinh dưỡng bổ sung (nếu có)
              if (_result!.containsKey('sugar') ||
                  _result!.containsKey('sodium') ||
                  _result!.containsKey('cholesterol')) ...[
                const SizedBox(height: 16),
                const Text(
                  'Dinh dưỡng bổ sung',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_result!.containsKey('sugar'))
                  _infoRow('Đường', '${_result!['sugar']} g'),
                if (_result!.containsKey('sodium'))
                  _infoRow('Natri', '${_result!['sodium']} mg'),
                if (_result!.containsKey('cholesterol'))
                  _infoRow('Cholesterol', '${_result!['cholesterol']} mg'),
              ],
              // Vitamins và Minerals (nếu có)
              if (_result!.containsKey('vitamins') &&
                  _result!['vitamins'] is Map) ...[
                const SizedBox(height: 16),
                const Text(
                  'Vitamin',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...(_result!['vitamins'] as Map<String, dynamic>).entries.map(
                  (e) => _infoRow(e.key, '${e.value}'),
                ),
              ],
              if (_result!.containsKey('minerals') &&
                  _result!['minerals'] is Map) ...[
                const SizedBox(height: 16),
                const Text(
                  'Khoáng chất',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...(_result!['minerals'] as Map<String, dynamic>).entries.map(
                  (e) => _infoRow(e.key, '${e.value}'),
                ),
              ],
              // Thành phần
              if (_result!.containsKey('ingredients') &&
                  (_result!['ingredients'] is List)) ...[
                const SizedBox(height: 16),
                const Text(
                  'Thành phần',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: List<String>.from(
                    _result!['ingredients'],
                  ).map((e) => Chip(label: Text(e))).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
