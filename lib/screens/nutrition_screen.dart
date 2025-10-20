import 'package:flutter/material.dart';
import 'package:gym_now/models/nutrition_model.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({Key? key}) : super(key: key);

  // Dữ liệu giả về các bài viết dinh dưỡng
  final List<NutritionArticle> articles = const [
    NutritionArticle(
      title: '5 loại thực phẩm giúp phục hồi cơ bắp',
      description: 'Sau mỗi buổi tập, cơ thể cần được nạp năng lượng để phục hồi và phát triển. Hãy khám phá ngay...',
      imageUrl: 'https://images.unsplash.com/photo-1543362906-acfc16c67564?auto=format&fit=crop&q=80&w=2069',
    ),
    NutritionArticle(
      title: 'Uống đủ nước quan trọng như thế nào?',
      description: 'Nước chiếm 70% cơ thể và là yếu tố không thể thiếu cho mọi hoạt động, đặc biệt là khi luyện tập.',
      imageUrl: 'https://images.unsplash.com/photo-1611526741060-64b55f75d5ab?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1926',
    ),
    NutritionArticle(
      title: 'Bữa sáng lý tưởng cho người tập gym',
      description: 'Bữa sáng cung cấp năng lượng cho cả ngày dài. Đừng bỏ lỡ những gợi ý tuyệt vời này.',
      imageUrl: 'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&q=80&w=2070',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Góc Dinh dưỡng'),
      ),
      body: ListView.builder(
        itemCount: articles.length,
        itemBuilder: (context, index) {
          final article = articles[index];
          return Card(
            color: const Color(0xFF1B263B),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            clipBehavior: Clip.antiAlias, // Để bo góc cả ảnh
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ảnh minh hoạ
                Image.network(
                  article.imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                // Tiêu đề và mô tả
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                        article.title,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        article.description,
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      ),
                    ],
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