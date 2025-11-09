import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugPaintSizeEnabled;
import 'package:gym_now/screens/splash_screen.dart';
import 'package:gym_now/widgets/network_banner.dart';
import 'package:intl/date_symbol_data_local.dart'; // **<-- ĐÃ SỬA**
import 'package:flutter_localizations/flutter_localizations.dart'; // **<-- THÊM MỚI**

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeDateFormatting('vi_VN', null);

  // Tắt debug paint để loại bỏ viền xanh
  debugPaintSizeEnabled = false;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymNow Fitness',
      debugShowCheckedModeBanner: false, // Tắt banner DEBUG
      // **PHẦN THÊM MỚI ĐỂ HỖ TRỢ TIẾNG VIỆT**
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('vi', 'VN')],

      // **KẾT THÚC PHẦN THÊM MỚI**
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
        primaryColor: const Color(0xFF0D1B2A),
        fontFamily: 'Poppins',

        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF8C00),
          secondary: Color(0xFF3A86FF),
          background: Color(0xFF0D1B2A),
          onPrimary: Colors.white,
          onBackground: Colors.white,
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D1B2A),
          elevation: 0,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFFFF8C00),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),

        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.white70),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white38),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFFF8C00)),
          ),
        ),

        textTheme: Theme.of(
          context,
        ).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
      ),
      home: const SplashScreen(),
      builder: (context, child) {
        return NetworkBanner(child: child ?? const SizedBox());
      },
    );
  }
}
