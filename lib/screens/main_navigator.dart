import 'package:flutter/material.dart';
import 'package:gym_now/screens/home_screen.dart';
import 'package:gym_now/screens/profile_screen.dart'; // Sẽ tạo ở bước 2
import 'package:gym_now/screens/nutrition_screen.dart';
import 'package:gym_now/screens/statistics_screen.dart'; // Sẽ tạo ở bước 2
import 'package:gym_now/screens/journal_screen.dart';

class MainNavigator extends StatefulWidget {
  const MainNavigator({Key? key}) : super(key: key);

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  // Index của tab đang được chọn
  int _selectedIndex = 0;

  // Danh sách các màn hình tương ứng với các tab
  static final List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    const StatisticsScreen(), // Màn hình thống kê
    const JournalScreen(), // Màn hình nhật ký
    const NutritionScreen(), // Màn hình dinh dưỡng
    const ProfileScreen(), // Màn hình hồ sơ
  ];

  // Hàm được gọi khi người dùng nhấn vào một tab
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Hiển thị màn hình được chọn từ danh sách
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      // Thanh điều hướng dưới
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Quan trọng khi có >= 4 tab
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Thống kê',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fastfood),
            label: 'Nhật ký',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Dinh dưỡng',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Hồ sơ'),
        ],
        currentIndex: _selectedIndex,
        backgroundColor: const Color(0xFF1B263B), // Màu nền của thanh nav
        selectedItemColor: Theme.of(
          context,
        ).colorScheme.primary, // Màu cam cho tab được chọn
        unselectedItemColor: Colors.grey, // Màu xám cho các tab khác
        onTap: _onItemTapped, // Gọi hàm khi tab được nhấn
      ),
    );
  }
}
