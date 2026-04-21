import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugPaintSizeEnabled;
import 'package:get/get.dart';
import 'package:gym_now/screens/splash_screen.dart';
import 'package:gym_now/services/notification_service.dart';
import 'package:gym_now/widgets/network_banner.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Clean Architecture & MVVM Imports
import 'package:gym_now/data/datasources/auth_remote_datasource.dart';
import 'package:gym_now/data/repositories_impl/auth_repository_impl.dart';
import 'package:gym_now/domain/usecases/auth_usecases.dart';
import 'package:gym_now/presentation/viewmodels/auth_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeDateFormatting('vi_VN', null);

  // Khởi tạo notification service
  await NotificationService().initialize();

  // Tắt debug paint để loại bỏ viền xanh
  debugPaintSizeEnabled = false;

  // Khởi tạo các dependency (Dependency Injection)
  _setupDependencies();

  runApp(const MyApp());
}

void _setupDependencies() {
  // Data Layer
  Get.lazyPut<AuthRemoteDataSource>(() => AuthRemoteDataSourceImpl());
  Get.lazyPut<AuthRepositoryImpl>(() => AuthRepositoryImpl(remoteDataSource: Get.find<AuthRemoteDataSource>()));

  // Domain Layer
  Get.lazyPut<AuthUseCases>(() => AuthUseCases(Get.find<AuthRepositoryImpl>()));

  // Presentation Layer (ViewModel)
  // Sử dụng Get.put để ViewModel luôn tồn tại
  Get.put(AuthViewModel(authUseCases: Get.find<AuthUseCases>()), permanent: true);
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'GymNow Fitness',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('vi', 'VN')],
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
        primaryColor: const Color(0xFF0D1B2A),
        fontFamily: 'Poppins',

        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF8C00),
          secondary: Color(0xFF3A86FF),
          surface: Color(0xFF0D1B2A),
          onPrimary: Colors.white,
          onSurface: Colors.white,
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
